# STUN/TURN Testing Guide - Goal 2 Phase 1

## Automated Tests Completed ✅

- ✅ Coturn container builds successfully
- ✅ Coturn listens on port 3478 (STUN/TURN)
- ✅ Coturn listens on port 5349 (TLS/DTLS)
- ✅ SFU server connects to coturn
- ✅ ICE servers configured correctly in SFU
- ✅ HTTP endpoint accessible

## Manual Browser Testing Required

### Test 1: Basic Connectivity
1. Open http://localhost:8080 in **Chrome/Edge**
2. Allow camera/microphone permissions
3. Open browser DevTools (F12) → Console tab
4. Look for ICE candidate gathering logs
5. **Expected**: Should see `srflx` (STUN) candidates

### Test 2: Two-Peer Video Call
1. Open http://localhost:8080 in **two browser windows**
2. Allow permissions in both windows
3. Verify both peers can see/hear each other
4. **Expected**: Video and audio streaming works

### Test 3: TURN Relay (NAT Simulation)
This requires simulating restrictive network conditions. For now, verify TURN credentials are being sent.

#### In Browser DevTools:
```javascript
// Check ICE configuration
console.log('Checking peer connection configuration...');
// Look for TURN server in the RTCPeerConnection
```

### Test 4: Inspect ICE Candidates
In browser console, watch for:
- `host` candidates (local IP)
- `srflx` candidates (STUN reflexive - your public IP)
- `relay` candidates (TURN relay - coturn IP)

```
Example ICE candidate log:
candidate:1 1 UDP 2130706431 192.168.1.100 54321 typ host
candidate:2 1 UDP 1694498815 203.0.113.1 54322 typ srflx raddr 192.168.1.100 rport 54321
candidate:3 1 UDP 16777215 172.19.0.2 49152 typ relay raddr 203.0.113.1 rport 54322
```

## Verify STUN Server Externally

You can use online tools to test STUN:
- https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/
- Set STUN server to: `stun:localhost:3478`
- **Expected**: Should gather STUN candidates

## Verify TURN Server

### Using trickle-ice tool:
1. Go to https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/
2. Add TURN server:
   - URI: `turn:localhost:3478`
   - Username: `sfuuser`
   - Password: `sfupass123`
3. Click "Gather candidates"
4. **Expected**: Should see `relay` type candidates

## Check Coturn Logs

```bash
# View coturn logs
docker logs coturn-server -f

# Look for:
# - "session 001: realm <sfu.local> user <sfuuser>"
# - "session 001: new TCP/UDP relay"
# - "session 001: closed"
```

## Check SFU Logs

```bash
# View SFU logs
docker logs sfu-server -f

# Look for:
# - "ICE Servers configured: STUN=stun:coturn-server:3478, TURN=turn:coturn-server:3478"
# - WebRTC connection establishment
# - Track forwarding logs
```

## Common Issues

### No STUN candidates
- **Symptom**: Only `host` candidates appear
- **Solution**: Check coturn is running: `docker ps | grep coturn`
- **Verify**: `docker exec coturn-server netstat -tuln | grep 3478`

### No TURN candidates
- **Symptom**: No `relay` candidates appear
- **Possible causes**:
  1. Wrong credentials in SFU environment variables
  2. Coturn not accepting connections
  3. Firewall blocking UDP ports 49152-49200
- **Check**: View coturn logs for auth failures

### TURN authentication fails
- **Symptom**: "401 Unauthorized" in coturn logs
- **Solution**: Verify credentials match:
  - SFU environment: `TURN_USERNAME=sfuuser`, `TURN_PASSWORD=sfupass123`
  - Coturn config: `user=sfuuser:sfupass123`

## Success Criteria

✅ **Phase 1 Complete When**:
1. Two browsers can establish video call via SFU
2. ICE candidates include `host` and `srflx` types
3. No errors in coturn logs
4. SFU logs show successful ICE configuration
5. Media (video/audio) flows between peers

## Next Steps

After manual testing confirms Phase 1 works:
- **Phase 2**: Implement better network isolation (separate Docker networks)
- **Phase 3**: Production hardening (dynamic credentials, TLS, metrics)

---

**Last Updated**: February 2, 2026
