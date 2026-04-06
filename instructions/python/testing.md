---
# noinspection YAMLUnresolvedAlias
globs: **/test_*.py, **/*_test.py, **/tests/**/*.py, **/conftest.py
---

# Python Testing

## Framework

Use `pytest`. Do not use `unittest` in new code.

## File and Function Naming

- Test files: `test_<module>.py` (preferred) or `<module>_test.py` (accepted if the project already uses it)
- Test functions: `def test_<scenario>():` using complete descriptive phrases
- Fixtures live in `conftest.py` at the closest relevant scope

## Structure

- One assertion concept per test. Multiple `assert` lines are fine if they verify one behaviour
- No setup/teardown via classes; use fixtures
- Parameterise with `@pytest.mark.parametrize` rather than copy-pasting tests
- Use `tmp_path` and `monkeypatch` fixtures over manual temp files or `unittest.mock.patch`

## Assertions

- Use plain `assert` statements; pytest rewrites them for good failure messages
- For exceptions: `with pytest.raises(ValueError, match="..."):`
- Never catch-and-assert: if you want to assert an exception, use `pytest.raises`

## What Not to Mock

- Do not mock the code under test
- Do not mock pure functions or data classes
- Mock only at boundaries: network, filesystem (when `tmp_path` is not enough), clocks, randomness
