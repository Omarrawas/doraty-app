#!/bin/bash
echo "Starting Vercel build script..."

# Install Flutter if not present
if [ ! -d "flutter" ]; then 
  git clone https://github.com/flutter/flutter.git -b stable
fi

# Ensure necessary directories and files exist
mkdir -p assets/images
touch assets/images/placeholder.png

# Generate .env file from Vercel environment variables
echo "Generating .env file..."
cat <<EOF > .env
SUPABASE_URL=$SUPABASE_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
ENCRYPTION_KEY=$ENCRYPTION_KEY
GOOGLE_WEB_CLIENT_ID=$GOOGLE_WEB_CLIENT_ID
GOOGLE_IOS_CLIENT_ID=$GOOGLE_IOS_CLIENT_ID
GOOGLE_ANDROID_CLIENT_ID=$GOOGLE_ANDROID_CLIENT_ID
DORATY_GITHUB_TOKEN=$DORATY_GITHUB_TOKEN
YouTube_Data_API_v3=$YouTube_Data_API_v3
EOF

echo "Running flutter pub get..."
./flutter/bin/flutter pub get

echo "Running build_runner to generate files (like multi_env.g.dart)..."
./flutter/bin/flutter pub run build_runner build --delete-conflicting-outputs

echo "Building Flutter Web..."
./flutter/bin/flutter build web --release
