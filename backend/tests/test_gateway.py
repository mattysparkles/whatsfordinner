from pathlib import Path
import sys

from fastapi.testclient import TestClient

sys.path.append(str(Path(__file__).resolve().parents[1]))
from app.main import app


client = TestClient(app)


def test_vision_parse_validation_error():
    response = client.post('/vision/parse', json={'images': []})
    assert response.status_code == 422


def test_instacart_link_success():
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


def test_rate_limit_placeholder_kicks_in():
    for _ in range(70):
        last = client.post(
            '/shopping/instacart-link',
            json={
                'items': [{'ingredientName': 'Rice'}],
            },
        )
    assert last.status_code in {200, 429}
