import { BaseWallet, BytesLike, ethers } from "ethers";
import {ec} from "elliptic";

const secp256k1EC = new ec("secp256k1");

// cspell:words hexlify

export function getPublicKey(wallet: BaseWallet): [BytesLike, BytesLike] {
    const publicKey = secp256k1EC.keyFromPrivate(wallet.privateKey.slice(2)).getPublic();
    const pubA = ethers.zeroPadValue(ethers.hexlify(publicKey.getX().toBuffer()), 32);
    const pubB = ethers.zeroPadValue(ethers.hexlify(publicKey.getY().toBuffer()), 32);
    return [pubA, pubB];
}
