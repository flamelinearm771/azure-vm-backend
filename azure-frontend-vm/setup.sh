#!/bin/bash

# Frontend Setup & Launch Script
# This script helps you get started quickly

set -e  # Exit on error

echo "🚀 QuickClip Frontend Setup & Launch"
echo "===================================="
echo ""

# Check Node.js
echo "✓ Checking Node.js..."
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please install Node.js 18+"
    exit 1
fi
NODE_VERSION=$(node -v)
echo "  Found: $NODE_VERSION"
echo ""

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ package.json not found. Run this script from the frontend directory."
    exit 1
fi

# Install or update dependencies
echo "📦 Installing dependencies..."
if [ ! -d "node_modules" ]; then
    npm install
else
    echo "  Dependencies already installed"
fi
echo ""

# Check/create .env.local
echo "⚙️  Checking configuration..."
if [ ! -f ".env.local" ]; then
    echo "❌ .env.local not found!"
    echo "   Creating with default values..."
    cat > .env.local << 'EOF'
NEXT_PUBLIC_BACKEND_URL=http://localhost:3000
EOF
    echo "   Created .env.local"
else
    echo "   .env.local found"
    echo "   Backend URL: $(grep NEXT_PUBLIC_BACKEND_URL .env.local)"
fi
echo ""

# Show startup options
echo "🎯 What would you like to do?"
echo ""
echo "1) Start development server (npm run dev)"
echo "2) Build for production (npm run build)"
echo "3) Start production server (npm start)"
echo "4) Run linter (npm run lint)"
echo "5) Just show configuration and exit"
echo ""
echo "Enter choice (1-5) [default: 1]:"
read -r choice

choice=${choice:-1}

case $choice in
    1)
        echo ""
        echo "🌐 Starting development server..."
        echo "   Open http://localhost:3000 in your browser"
        echo ""
        npm run dev
        ;;
    2)
        echo ""
        echo "🏗️  Building for production..."
        npm run build
        echo ""
        echo "✅ Build complete!"
        echo "   Run 'npm start' to start production server"
        ;;
    3)
        echo ""
        echo "🚀 Starting production server..."
        echo "   Open http://localhost:3000 in your browser"
        echo ""
        npm start
        ;;
    4)
        echo ""
        echo "🔍 Running linter..."
        npm run lint
        ;;
    5)
        echo ""
        echo "📋 Current Configuration:"
        echo "========================"
        echo ""
        echo "Backend URL:"
        grep NEXT_PUBLIC_BACKEND_URL .env.local
        echo ""
        echo "Node version:"
        node -v
        echo ""
        echo "npm version:"
        npm -v
        echo ""
        echo "Next.js version:"
        npm list next | head -2
        echo ""
        echo "To start development server, run:"
        echo "  npm run dev"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
