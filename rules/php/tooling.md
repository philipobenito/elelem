---
# noinspection YAMLUnresolvedAlias
globs: **/composer.json, **/composer.lock
---

# PHP Tooling

## Project Layout

Use PSR-4 autoloading with a standard layout:

```
project/
  composer.json
  composer.lock
  src/
    (application code)
  tests/
    (test files)
  vendor/
  public/
    index.php (web entry point)
```

## Dependency Management

- `composer.json` is the single source of truth for dependencies and metadata
- Never edit `composer.lock` by hand; it's managed by Composer
- Use `composer require <package>` to add dependencies
- Use `composer require --dev <package>` for development dependencies
- Run `composer install` to install from lock file (production/CI)
- Run `composer update` to update dependencies within version constraints
- Use PSR-4 autoloading in `composer.json`: `"psr-4": {"App\\": "src/"}`

## Formatting and Linting

- Formatter: `PHP-CS-Fixer` or `PHP_CodeSniffer` with PSR-12 standard
- Linter: `PHPStan` (level 8+) or `Psalm` for static analysis
- Run `composer validate` to check composer.json validity
- Never suppress static analysis errors with `@phpstan-ignore` without a comment explaining why

## Build and Run

- Use Composer scripts in `composer.json` for common tasks: `test`, `lint`, `fix`, `analyse`
- Use `composer dump-autoload -o` for optimised autoloading in production
- Use `php -S localhost:8000` for quick development server
- Use proper web servers (nginx + PHP-FPM) for production
- Enable OPcache in production for performance
- Use `composer install --no-dev --optimize-autoloader` for production deployments
