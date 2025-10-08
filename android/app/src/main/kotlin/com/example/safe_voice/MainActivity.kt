package com.example.safe_voice

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Address
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.*

class MainActivity : FlutterActivity() {
    private lateinit var locationChannel: MethodChannel
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var geocoder: Geocoder
    
    companion object {
        const val LOCATION_PERMISSION_REQUEST_CODE = 1001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize location services
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        geocoder = Geocoder(this, Locale.getDefault())
        
        // Setup method channel for location
        locationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "safe_voice/location"
        )
        
        locationChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentLocationWithAddress" -> getCurrentLocationWithAddress(result)
                "requestLocationPermission" -> requestLocationPermission(result)
                "isLocationServiceEnabled" -> isLocationServiceEnabled(result)
                "openLocationSettings" -> openLocationSettings(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun getCurrentLocationWithAddress(result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            result.error("PERMISSION_DENIED", "Location permission not granted", null)
            return
        }

        if (!isLocationEnabled()) {
            result.error("LOCATION_DISABLED", "Location services are disabled", null)
            return
        }

        try {
            fusedLocationClient.lastLocation.addOnSuccessListener { location: Location? ->
                if (location != null) {
                    getAddressFromLocation(location, result)
                } else {
                    // Request fresh location
                    requestFreshLocation(result)
                }
            }.addOnFailureListener { exception ->
                result.error("LOCATION_ERROR", "Failed to get location: ${exception.message}", null)
            }
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Location permission denied", null)
        } catch (e: Exception) {
            result.error("LOCATION_ERROR", "Unexpected error: ${e.message}", null)
        }
    }

    private fun requestFreshLocation(result: MethodChannel.Result) {
        val locationRequest = LocationRequest.create().apply {
            priority = LocationRequest.PRIORITY_HIGH_ACCURACY
            interval = 10000
            fastestInterval = 5000
            numUpdates = 1
        }

        val locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                val location = locationResult.lastLocation
                if (location != null) {
                    getAddressFromLocation(location, result)
                } else {
                    result.success("Unable to detect precise location")
                }
                fusedLocationClient.removeLocationUpdates(this)
            }
        }

        try {
            fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, null)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Location permission denied", null)
        }
    }

    private fun getAddressFromLocation(location: Location, result: MethodChannel.Result) {
        try {
            if (Geocoder.isPresent()) {
                val addresses: List<Address>? = geocoder.getFromLocation(
                    location.latitude, 
                    location.longitude, 
                    1
                )

                if (!addresses.isNullOrEmpty()) {
                    val address = addresses[0]
                    val addressText = buildString {
                        address.thoroughfare?.let { append("$it, ") }
                        address.locality?.let { append("$it, ") }
                        address.adminArea?.let { append("$it, ") }
                        address.countryName?.let { append(it) }
                    }.trimEnd(',', ' ')

                    if (addressText.isNotEmpty()) {
                        result.success(addressText)
                    } else {
                        result.success("${location.latitude}, ${location.longitude}")
                    }
                } else {
                    result.success("${location.latitude}, ${location.longitude}")
                }
            } else {
                result.success("${location.latitude}, ${location.longitude}")
            }
        } catch (e: Exception) {
            result.success("${location.latitude}, ${location.longitude}")
        }
    }

    private fun requestLocationPermission(result: MethodChannel.Result) {
        if (hasLocationPermission()) {
            result.success(true)
            return
        }

        ActivityCompat.requestPermissions(
            this,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ),
            LOCATION_PERMISSION_REQUEST_CODE
        )
        result.success(true)
    }

    private fun isLocationServiceEnabled(result: MethodChannel.Result) {
        result.success(isLocationEnabled())
    }

    private fun openLocationSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
            result.success(null)
        } catch (e: Exception) {
            result.error("SETTINGS_ERROR", "Unable to open location settings", null)
        }
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun isLocationEnabled(): Boolean {
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }
}
