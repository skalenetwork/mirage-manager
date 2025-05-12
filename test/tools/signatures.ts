import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { BytesLike, ethers, dataSlice, SigningKey, HDNodeWallet, hashMessage } from "ethers";

export async function getPublicKey(signer: HDNodeWallet | HardhatEthersSigner): Promise<[BytesLike, BytesLike]> {
    const digest = hashMessage("random");
    const pubKey = SigningKey.recoverPublicKey(
        digest,
        await signer.signMessage("random")
    );
    const pubA = ethers.zeroPadValue(dataSlice(pubKey, 1, 33), 32);
    const pubB = ethers.zeroPadValue(dataSlice(pubKey, 33), 32);
    return [pubA, pubB];
}
