from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class VisionImageInput(BaseModel):
    image_id: str = Field(alias="imageId", min_length=1, max_length=128)
    category: Literal["fridge", "pantry", "receipt", "other"]
    mime_type: str = Field(alias="mimeType", min_length=3, max_length=100)
    base64_data: str = Field(alias="base64Data", min_length=8)

    model_config = ConfigDict(populate_by_name=True)


class VisionParseRequest(BaseModel):
    images: list[VisionImageInput] = Field(min_length=1, max_length=8)


class IngredientCandidate(BaseModel):
    source_image_id: str = Field(alias="sourceImageId")
    raw_text_or_cue: str = Field(alias="rawTextOrCue")
    suggested_ingredient_name: str = Field(alias="suggestedIngredientName")
    confidence_score: float = Field(alias="confidenceScore", ge=0.0, le=1.0)
    confidence_class: Literal["likely", "possible", "unclear"] = Field(alias="confidenceClass")
    ingredient_category: str = Field(alias="ingredientCategory")
    quantity: float | None = None
    unit: str | None = None
    why_detected: str = Field(alias="whyDetected")

    model_config = ConfigDict(populate_by_name=True)


class VisionParseResponse(BaseModel):
    ingredient_candidates: list[IngredientCandidate] = Field(alias="ingredientCandidates")

    model_config = ConfigDict(populate_by_name=True)


class PantryItemInput(BaseModel):
    id: str = Field(min_length=1)
    name: str = Field(min_length=1)
    quantity: float | None = None
    unit: str | None = None


class UserPreferencesInput(BaseModel):
    dietary_filters: list[str] = Field(default_factory=list, alias="dietaryFilters")
    preference_filters: list[str] = Field(default_factory=list, alias="preferenceFilters")

    model_config = ConfigDict(populate_by_name=True)


class RecipeSuggestRequest(BaseModel):
    pantry_items: list[PantryItemInput] = Field(alias="pantryItems", max_length=200)
    meal_type: Literal["breakfast", "lunch", "dinner", "snack"] = Field(alias="mealType")
    preferences: UserPreferencesInput
    servings: int = Field(ge=1, le=12)

    model_config = ConfigDict(populate_by_name=True)


class RecipeSuggestResponse(BaseModel):
    suggestions: list[dict[str, Any]]


class ShoppingListItemInput(BaseModel):
    ingredient_name: str = Field(alias="ingredientName", min_length=1)
    quantity: float | None = None
    unit: str | None = None
    note: str | None = None

    model_config = ConfigDict(populate_by_name=True)


class InstacartLinkRequest(BaseModel):
    recipe_title: str | None = Field(default=None, alias="recipeTitle")
    items: list[ShoppingListItemInput] = Field(min_length=1, max_length=200)

    model_config = ConfigDict(populate_by_name=True)

    @field_validator("recipe_title")
    @classmethod
    def normalize_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        trimmed = value.strip()
        return trimmed or None


class InstacartLinkResponse(BaseModel):
    checkout_url: str = Field(alias="checkoutUrl")
    message: str

    model_config = ConfigDict(populate_by_name=True)


class ErrorResponse(BaseModel):
    error_code: str = Field(alias="errorCode")
    user_message: str = Field(alias="userMessage")
    request_id: str = Field(alias="requestId")

    model_config = ConfigDict(populate_by_name=True)
