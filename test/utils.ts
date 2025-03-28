import { getBytes } from 'ethers';

export function ipv4StringToBytes(ip: string): string {
    const bytes = Uint8Array.from(ip.split('.').map(Number));
    if (bytes.length !== 4) {
        throw new Error("Invalid IP format");
    }
    return `0x${Buffer.from(bytes).toString('hex')}`;
}

export function bytesToIpv4String(ipBytes: string): string {
    const bytes = getBytes(ipBytes); // e.g., "0xc0a80001" → Uint8Array [192, 168, 0, 1]
    if (bytes.length !== 4) {
        throw new Error("Expected a 4-byte IP address");
    }
    return bytes.join('.');
  }
