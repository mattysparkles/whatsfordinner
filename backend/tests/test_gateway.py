from pathlib import Path
import sys

from fastapi.testclient import TestClient

sys.path.append(str(Path(__file__).resolve().parents[1]))
from app import main
from app.main import app, _ai_response_cache, _device_quota_window, _instacart_url_cache, _rate_window, _user_quota_window


client = TestClient(app)


def setup_function() -> None:
    _instacart_url_cache.clear()
    _ai_response_cache.clear()
    _user_quota_window.clear()
    _device_quota_window.clear()
    _rate_window.clear()


def test_vision_parse_validation_error():
    response = client.post('/vision/parse', json={'images': []})
    assert response.status_code == 422


def test_instacart_link_success_recipe_mode():
    response = client.post(
        '/shopping/instacart-link',
        json={
            'recipeTitle': 'Lemon Pasta',
            'items': [{'ingredientName': 'Lemon', 'quantity': 2, 'unit': 'count'}],
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert 'checkoutUrl' in body
    assert 'instacart.com' in body['checkoutUrl']
    assert body['pageType'] == 'recipe'
    assert body['fromCache'] is False


def test_instacart_link_uses_cache_for_stable_fingerprint():
    payload = {
        'items': [
            {'ingredientName': 'Chicken breast', 'quantity': 2, 'unit': 'lb', 'note': 'organic'},
            {'ingredientName': 'Rice', 'quantity': 1, 'unit': 'bag'},
        ]
    }
    first = client.post('/shopping/instacart-link', json=payload)
    second = client.post('/shopping/instacart-link', json=payload)

    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()['fromCache'] is True
    assert first.json()['checkoutUrl'] == second.json()['checkoutUrl']


def test_rate_limit_placeholder_kicks_in():
    for _ in range(70):
        last = client.post(
            '/shopping/instacart-link',
            json={
                'items': [{'ingredientName': 'Rice'}],
            },
        )
    assert last.status_code in {200, 429}


def test_recipe_suggest_uses_ai_cache(monkeypatch):
    calls = {'count': 0}

    async def _fake_openai(*_args, **_kwargs):
        calls['count'] += 1
        response = {'choices': [{'message': {'content': '{"suggestions":[{"title":"Rice Bowl"}]}'}}]}
        _ai_response_cache[(_kwargs['meter_kind'], _kwargs['cache_key'])] = main._AICacheEntry(
            value=response,
            expires_at=main.datetime.now(main.UTC) + main.timedelta(seconds=60),
        )
        return response

    monkeypatch.setattr(main.settings, 'openai_api_key', 'test-key')
    monkeypatch.setattr(main, '_openai_chat_completion', _fake_openai)

    payload = {
        'pantryItems': [{'id': '1', 'name': 'Rice'}],
        'mealType': 'dinner',
        'preferences': {'dietaryFilters': [], 'preferenceFilters': []},
        'servings': 2,
    }
    first = client.post('/recipes/suggest', headers={'x-user-id': 'u1', 'x-device-id': 'd1'}, json=payload)
    second = client.post('/recipes/suggest', headers={'x-user-id': 'u1', 'x-device-id': 'd1'}, json=payload)

    assert first.status_code == 200
    assert second.status_code == 200
    assert calls['count'] == 1


def test_user_quota_applies(monkeypatch):
    monkeypatch.setattr(main.settings, 'user_quota_per_hour', 1)
    first = client.post(
        '/shopping/instacart-link',
        headers={'x-user-id': 'quota-user', 'x-device-id': 'quota-device'},
        json={'items': [{'ingredientName': 'Rice'}]},
    )
    second = client.post(
        '/shopping/instacart-link',
        headers={'x-user-id': 'quota-user', 'x-device-id': 'quota-device'},
        json={'items': [{'ingredientName': 'Beans'}]},
    )
    assert first.status_code == 200
    assert second.status_code == 429
    assert second.json()['errorCode'] == 'quota_exceeded'
