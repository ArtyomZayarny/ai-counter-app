from decimal import Decimal


def calculate_cost(consumed_units: Decimal, tariff_per_unit: Decimal) -> Decimal:
    """Calculate total cost = consumed_units * tariff_per_unit, rounded to 2 decimal places."""
    return (consumed_units * tariff_per_unit).quantize(Decimal("0.01"))
