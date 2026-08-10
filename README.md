# CMS-Aligned Network Implementation Guide

This project contains the FHIR Shorthand (FSH) source files and static page content for building the CMS-Aligned Network Implementation Guide.

## Prerequisites

1. **Node.js** (v18+) & **SUSHI**:
   ```bash
   npm install -g fsh-sushi
   ```
2. **Java JDK** (v17+):
   Required by the HL7 IG Publisher.
3. **Ruby** (v3.0+) & **Jekyll**:
   Required by the HL7 IG Publisher template engine.
   - On macOS via Homebrew:
     ```bash
     brew install ruby
     export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH"
     gem install jekyll bundler
     ```

## How to Compile & View the Implementation Guide

### Quick Build (SUSHI + IG Publisher)

Run the included `./_genonce.sh` script to perform a full build:

```bash
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH"
./_genonce.sh
```

### Viewing the Output

Once the build completes successfully, open `output/index.html` in your web browser:

```bash
open output/index.html
```

### Fast Validation (FSH Only)

If you only want to validate FHIR Shorthand (`.fsh`) files without running the full HTML template publisher:

```bash
sushi .
```

## Directory Structure

- `input/page-content/`: Markdown content for IG sections (e.g., `index.md`, `registration.md`).
- `input/fsh/`: FHIR Shorthand definitions (`.fsh` files).
- `sushi-config.yaml`: Implementation Guide configuration and menu structure.
- `ig.ini`: IG Publisher initial setup file.
- `output/`: The generated static HTML website.
