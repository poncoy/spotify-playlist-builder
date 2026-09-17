#!/bin/bash
cd "$(dirname "$0")"

echo "🎵 LaSedlist - Spotify Playlist Builder"
echo "========================================"
echo ""

python3 -m spotify_playlist_builder

echo ""
read -p "Presioná Enter para cerrar esta ventana..."
