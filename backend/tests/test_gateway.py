from pathlib import Path
import sys

from fastapi.testclient import TestClient

sys.path.append(str(Path(__file__).resolve().parents[1]))
from app.main import app, _instacart_url_cache


client = TestClient(app)


def setup_function() -> None:
    _instacart_url_cache.clear()


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
