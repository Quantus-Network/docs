# Quantus Network Documentation

This repository contains the documentation for the Quantus Network project. The documentation is built using MkDocs with the Material theme.

## Local Development

### Prerequisites

- Python 3.7 or higher
- pip (Python package manager)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/quantus-network/docs.git
cd docs
```

2. Create and activate a virtual environment (recommended):
```bash
# On macOS/Linux
python -m venv venv
source venv/bin/activate

# On Windows
python -m venv venv
.\venv\Scripts\activate
```

3. Install required packages:
```bash
pip install -r requirements.txt
```

### Running Documentation Locally

1. Start the development server:
```bash
mkdocs serve
```

2. Open your browser and navigate to `http://127.0.0.1:8000`

The documentation will automatically reload when you make changes to the source files.

### Building Documentation

To build the documentation for production:

```bash
mkdocs build
```

This will create a `site` directory containing the built documentation.

## Publishing to GitHub Pages

### Automatic Deployment (Recommended)

1. Ensure your repository has GitHub Actions enabled
2. Push your changes to the main branch:
```bash
git add .
git commit -m "Update documentation"
git push origin main
```

The documentation will be automatically built and deployed to GitHub Pages.

### Manual Deployment

1. Build the documentation:
```bash
mkdocs build
```

2. Deploy to GitHub Pages:
```bash
mkdocs gh-deploy
```

## Project Structure

```
docs/
├── index.md            # Homepage
├── governance/         # Governance documentation
│   ├── path_0.md      # Path 0 documentation
│   ├── path_1.md      # Path 1 documentation
│   ├── path_2.md      # Path 2 documentation
│   ├── path_3.md      # Path 3 documentation
│   ├── path_4.md      # Path 4 documentation
│   ├── path_5.md      # Path 5 documentation
│   └── vesting_scenarios.md  # Vesting scenarios
├── mkdocs.yml         # MkDocs configuration
├── requirements.txt   # Python dependencies
└── README.md         # This file
```

## Common Issues and Solutions

### Missing Dependencies

If you encounter missing dependency errors, ensure you have installed all requirements:
```bash
pip install -r requirements.txt
```

### Port Already in Use

If port 8000 is already in use, you can specify a different port:
```bash
mkdocs serve -a 127.0.0.1:8001
```

### Build Errors

If you encounter build errors:
1. Check the MkDocs configuration in `mkdocs.yml`
2. Ensure all referenced files exist
3. Check for syntax errors in Markdown files

## Additional Resources

- [MkDocs Documentation](https://www.mkdocs.org/)
- [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/)
- [Markdown Guide](https://www.markdownguide.org/)