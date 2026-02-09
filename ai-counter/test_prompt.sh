#!/bin/bash
RESULT=$(curl -s -X POST http://192.168.101.101:8000/recognize \
  -F "image=@/Users/artemzaiarnyi/Desktop/Screenshot 2026-02-09 at 20.23.00.png" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('result','ERROR'))")
echo "Got: $RESULT | Expected: 01814"
if [ "$RESULT" = "01814" ]; then echo "PASS"; else echo "FAIL"; fi
