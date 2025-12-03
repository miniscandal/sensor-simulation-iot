[CmdletBinding()]
param (
    # Device identifier (e.g., "A7"). Required.
    [Parameter(Mandatory = $true)]
    [string]$deviceId,

    # Status code that determines the message structure. Required.
    [Parameter(Mandatory = $true)]
    [int]$statusCode
)

# ─────────────────────────────────────────────────────────────
# MQTT broker configuration
# ─────────────────────────────────────────────────────────────
$brokerHost = "localhost"
$brokerPort = 1883
$topic = "web-iot-control-panel"

# Generate ISO 8601 timestamp in UTC
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# ─────────────────────────────────────────────────────────────
# Shared data blocks used across multiple message types
# ─────────────────────────────────────────────────────────────

# Static location block for all device messages
$location = @{
    lat     = 20.5244
    lng     = -99.8956
    zone    = "assembly"
    line    = "3"
    station = "welding robot"
}

# Function to generate realistic sensor readings
function Get-RandomSensorReadings {
    $humidity = [math]::Round((Get-Random -Minimum 0.0 -Maximum 100.0), 1)
    $temperature = [math]::Round((Get-Random -Minimum -40.0 -Maximum 80.0), 1)

    return @{
        temperature = $temperature
        humidity    = $humidity
    }
}

# ─────────────────────────────────────────────────────────────
# Message templates mapped by statusCode
# Each entry is a script block that returns a hashtable
# ─────────────────────────────────────────────────────────────
$messageTemplates = @{
    101 = {
        param($deviceId)
        @{
            deviceId        = $deviceId
            statusCode      = 101
            firmwareVersion = "1.3.0"
            location        = $location
            timestamp       = $timestamp
        }
    }

    102 = {
        param($deviceId)
        @{
            deviceId   = $deviceId
            statusCode = 102
            location   = $location
            timestamp  = $timestamp
        }
    }

    103 = {
        param($deviceId)
        @{
            deviceId   = $deviceId
            statusCode = 103
            location   = $location
            timestamp  = $timestamp
        }
    }

    
    104 = {
        param($deviceId)
        @{
            deviceId   = $deviceId
            statusCode = 104
            location   = $location
            timestamp  = $timestamp
        }
    }

    202 = {
        param($deviceId)
        @{
            deviceId       = $deviceId
            statusCode     = 202
            sensorReadings = Get-RandomSensorReadings
            timestamp      = $timestamp
        }
    }
}

# ─────────────────────────────────────────────────────────────
# Validate statusCode and build message payload
# ─────────────────────────────────────────────────────────────
if (-not $messageTemplates.ContainsKey($statusCode)) {
    Write-Error "(╯°□°）╯︵ ┻━┻ Unrecognized statusCode: $statusCode. Valid options are 101, 102, 103, 104 or 202."
    exit 1
}

try {
    # Invoke the corresponding template function with deviceId
    $messageObject = & $messageTemplates[$statusCode] $deviceId

    # Convert the hashtable to a JSON string with full depth
    $jsonMessage = $messageObject | ConvertTo-Json -Depth 5

    # Optional verbose output for debugging
    Write-Verbose "(・_・) Device '$deviceId' prepared message for status $statusCode."

    # Publish the message using mosquitto_pub
    & "mosquitto_pub.exe" -h $brokerHost -p $brokerPort -t $topic -m $jsonMessage
}
catch {
    # Catch and display any unexpected errors
    Write-Error "(×_×) Failed to build or publish message: $_"
    exit 1
}
