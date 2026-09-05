// Tipi di dominio del modulo 1r0-diet. Vedi docs/glossary.md per le definizioni
// e docs/adr/0017-modulo-dieta-scope.md e seguenti per le decisioni.

export type FoodSource = "openfoodfacts" | "usda" | "custom";

export interface Food {
  id: string;
  name: string;
  source: FoodSource;
  externalId?: string | null;
  barcode?: string | null;
  brand?: string | null;
  servingSizeG?: number | null;
  caloriesPer100g: number;
  proteinGPer100g: number;
  carbsGPer100g: number;
  fatGPer100g: number;
  caffeineMgPer100g?: number | null;
}

export interface Recipe {
  id: string;
  userId: string;
  name: string;
  notes?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface RecipeItem {
  id: string;
  recipeId: string;
  foodId: string;
  quantityG: number;
  orderIndex: number;
}

export type MealSlot = "breakfast" | "lunch" | "dinner" | "snack";

export interface MealEntry {
  id: string;
  userId: string;
  consumedAt: string;
  mealSlot: MealSlot;
  recipeId?: string | null;
  notes?: string | null;
  createdAt: string;
}

/** Macro snapshottati al momento del log — restano accurati anche se `Food` cambia dopo. */
export interface MealEntryItem {
  id: string;
  mealEntryId: string;
  foodId?: string | null;
  quantityG: number;
  calories: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
  orderIndex: number;
}

export type PlannedMealStatus = "planned" | "completed" | "skipped";

export interface PlannedMeal {
  id: string;
  userId: string;
  plannedDate: string;
  mealSlot: MealSlot;
  recipeId?: string | null;
  status: PlannedMealStatus;
  mealEntryId?: string | null;
  createdAt: string;
}

export interface PlannedMealItem {
  id: string;
  plannedMealId: string;
  foodId: string;
  quantityG: number;
  orderIndex: number;
}

export type ShoppingListItemSource = "generated" | "manual";

export interface ShoppingListItem {
  id: string;
  userId: string;
  foodId?: string | null;
  customName?: string | null;
  quantityText?: string | null;
  isChecked: boolean;
  source: ShoppingListItemSource;
  createdAt: string;
}

export interface WaterLog {
  id: string;
  userId: string;
  loggedAt: string;
  amountMl: number;
  createdAt: string;
}

export interface Supplement {
  id: string;
  userId: string;
  name: string;
  doseText?: string | null;
  scheduleText?: string | null;
  active: boolean;
  createdAt: string;
}

export interface SupplementLog {
  id: string;
  userId: string;
  supplementId: string;
  loggedAt: string;
  taken: boolean;
}

export interface CaffeineLog {
  id: string;
  userId: string;
  loggedAt: string;
  sourceName: string;
  caffeineMg: number;
  createdAt: string;
}

/** Modalità con cui viene calcolato l'obiettivo calorico/macro (vedi ADR-0019). */
export type NutritionGoalMode = "manual" | "phase_linked" | "tdee";

/**
 * Riga append-only: la riga attiva è la più recente con
 * `effectiveFrom <= oggi`. Cambiare obiettivo = inserire una nuova riga,
 * mai un update.
 */
export interface NutritionGoal {
  id: string;
  userId: string;
  mode: NutritionGoalMode;
  caloriesTarget: number;
  proteinGTarget: number;
  carbsGTarget: number;
  fatGTarget: number;
  waterMlTarget?: number | null;
  effectiveFrom: string;
  createdAt: string;
}

export function macroCalories(proteinG: number, carbsG: number, fatG: number): number {
  return proteinG * 4 + carbsG * 4 + fatG * 9;
}
