# Map Display on Web - Configuration Guide

## ✅ Changes Made for Web Map Support

### 1. Updated Content Security Policy (CSP)
**File**: `web/index.html`

Added explicit permissions for Mapbox tile servers:
- `connect-src`: Added `https://*.mapbox.com` and `https://api.mapbox.com`
- `img-src`: Added `https://*.mapbox.com` and `https://api.mapbox.com`
- `style-src`: Added `'unsafe-inline'` and `https:` for map styles

This ensures the browser allows loading map tiles from Mapbox servers.

### 2. Removed Google Maps API
**File**: `web/index.html`

Removed the Google Maps script tag since the app uses `flutter_map` with Mapbox tiles, not Google Maps. This prevents any conflicts.

```html
<!-- REMOVED -->
<script async defer src="https://maps.googleapis.com/maps/api/js?key=..."></script>
```

### 3. Added Map-Specific CSS
**File**: `web/styles.css` (NEW)

Created custom CSS to ensure proper map rendering:
- Canvas touch handling
- Proper container sizing
- Image rendering optimization
- Tile container pointer events
- Smooth scrolling

### 4. Linked CSS in HTML
**File**: `web/index.html`

Added link to the new styles.css file:
```html
<link rel="stylesheet" href="styles.css">
```

## 🗺️ Current Map Configuration

### flutter_map Package
- **Version**: 6.1.0
- **Platform Support**: ✅ Web, Android, iOS, Desktop
- **Tile Provider**: Mapbox

### Map Implementation
**File**: `lib/screens/field_operations_enhanced_screen.dart`

```dart
FlutterMap(
  mapController: _mapController,
  options: MapOptions(
    center: _currentLocation,
    zoom: 14.0,
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://api.mapbox.com/styles/v1/kazofficial/...',
      tileProvider: kIsWeb ? null : MapTileCacheService.getTileProvider(...),
    ),
    MarkerLayer(markers: _markers.toList()),
    PolylineLayer(polylines: {..._journeyPolylines, ..._routePolylines}.toList()),
  ],
)
```

### Web-Specific Handling
- **Tile Caching**: Disabled on web (uses network tiles directly)
- **Location Services**: Web geolocation API used automatically
- **Touch Events**: Properly configured for web interaction

## 🔧 Technical Details

### Why flutter_map Instead of Google Maps?

1. **Cross-Platform**: `flutter_map` works on all platforms including web
2. **No API Key Required**: Uses Mapbox tiles with your custom style
3. **Offline Support**: Supports tile caching on mobile (not web)
4. **Customizable**: Full control over map appearance and behavior

### Map Tile Provider (Mobile vs Web)

**Mobile**:
```dart
tileProvider: MapTileCacheService.getTileProvider(urlTemplate)
// Uses cached tiles for offline functionality
```

**Web**:
```dart
tileProvider: null
// Uses default network provider (no caching)
```

### Conditional Import for Web

The app uses conditional imports to handle platform differences:

```dart
import '../services/map_tile_cache_service.dart'
    if (dart.library.html) '../services/map_tile_cache_service_web.dart';
```

- **Mobile**: Full caching service with ObjectBox storage
- **Web**: Stub implementation that returns null (uses network only)

## 🧪 Testing the Map on Web

### 1. Run the App
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

### 2. Expected Behavior
- ✅ Map tiles load from Mapbox
- ✅ Current location marker appears (with browser permission)
- ✅ Site visit markers display correctly
- ✅ Map is interactive (pan, zoom, tap)
- ✅ Routes display when directions requested
- ✅ Smooth animations and transitions

### 3. Browser Console Checks
- No CSP (Content Security Policy) errors
- No CORS (Cross-Origin) errors
- Tiles load successfully from api.mapbox.com
- Location permission requested and granted

## 🐛 Troubleshooting

### Map Not Displaying
1. **Check Browser Console**: Look for CSP or CORS errors
2. **Clear Browser Cache**: Hard refresh (Ctrl+Shift+R)
3. **Check Network Tab**: Ensure map tiles are loading
4. **Verify Mapbox Token**: Check if the access token is valid

### Tiles Not Loading
- **CSP Issue**: Ensure `web/index.html` has Mapbox domains in CSP
- **Network Issue**: Check internet connection
- **Token Issue**: Verify Mapbox access token hasn't expired

### Location Not Working
- **Browser Permission**: Chrome will prompt for location access
- **HTTPS Required**: Geolocation API requires secure context
- **Default Location**: App falls back to Sudan coordinates (12.8628, 30.2176)

## 📝 Configuration Files Changed

1. **web/index.html**
   - Updated CSP to allow Mapbox
   - Removed Google Maps API script
   - Added link to styles.css

2. **web/styles.css** (NEW)
   - Canvas and touch handling
   - Map container sizing
   - Tile rendering optimization

3. **lib/services/map_tile_cache_service_web.dart** (EXISTING)
   - Web stub for mobile caching service
   - Returns null for tile provider on web

## ✨ Features Available on Web

- ✅ Interactive map with pan and zoom
- ✅ Current location tracking (with browser permission)
- ✅ Site visit markers with labels
- ✅ Color-coded markers by status
- ✅ Priority indicators on markers
- ✅ Route polylines for directions
- ✅ Journey tracking polylines
- ✅ Tap to select visits
- ✅ Real-time location updates

## 🚀 Performance Notes

### Web Optimizations
- Tiles are loaded on-demand from Mapbox CDN
- Images are cached by browser automatically
- No local database storage (faster initial load)
- Smooth 60fps animations on modern browsers

### Recommended Browsers
- ✅ Chrome 90+
- ✅ Edge 90+
- ✅ Firefox 88+
- ✅ Safari 14+

## 🔐 Security Considerations

### Content Security Policy
The CSP is configured to:
- Allow Mapbox tile servers
- Allow Supabase connections
- Block unsafe inline scripts (except for essential Flutter code)
- Prevent clickjacking attacks

### Privacy
- Location access requires user permission
- Location data sent to Supabase over HTTPS
- Map tiles loaded securely from Mapbox

## 📚 Resources

- [flutter_map Documentation](https://docs.fleaflet.dev/)
- [Mapbox Tile API](https://docs.mapbox.com/api/maps/raster-tiles/)
- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)

---

**Last Updated**: November 10, 2025
**Flutter Version**: 3.35.4
**flutter_map Version**: 6.1.0
