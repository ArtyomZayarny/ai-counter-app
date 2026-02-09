from app.validation import normalize_digits, validate_digit_count


class TestNormalizeDigits:
    def test_only_digits(self):
        assert normalize_digits("02340") == "02340"

    def test_strips_spaces(self):
        assert normalize_digits("0 2 3 4 0") == "02340"

    def test_strips_letters(self):
        assert normalize_digits("The digits are 02340.") == "02340"

    def test_strips_special_chars(self):
        assert normalize_digits("02-34-0\n") == "02340"

    def test_empty_string(self):
        assert normalize_digits("") == ""

    def test_no_digits(self):
        assert normalize_digits("no digits here") == ""

    def test_mixed_content(self):
        assert normalize_digits("Reading: 0-2-3-4-0 m³") == "02340"


class TestValidateDigitCount:
    def test_exactly_five(self):
        assert validate_digit_count("02340") is True

    def test_zero_digits(self):
        assert validate_digit_count("") is False

    def test_four_digits(self):
        assert validate_digit_count("0234") is False

    def test_six_digits(self):
        assert validate_digit_count("023401") is False

    def test_one_digit(self):
        assert validate_digit_count("5") is False
