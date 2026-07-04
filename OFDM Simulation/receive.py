import serial
import time

COM_PORT = 'COM4'
BAUD     = 115200
EXPECTED = 5760

print(f"Listening on {COM_PORT} at {BAUD} baud")
print("Press BTNU on your Nexys A7 when ready")

with serial.Serial(COM_PORT, BAUD, timeout=10) as ser:
    data = ser.read(EXPECTED)

print(f"\nReceived {len(data)} bytes")
if len(data) == EXPECTED:
    print("SUCCESS: complete frame received")
elif len(data) > 0:
    print(f"PARTIAL: got {len(data)}/{EXPECTED} bytes")
else:
    print("NOTHING received")

if data:
    print(f"\nFirst 32 bytes (hex):")
    print(' '.join(f'{b:02x}' for b in data[:32]))
    
    with open('rx_bytes.bin', 'wb') as f:
        f.write(data)
    print(f"\nSaved to rx_bytes.bin")