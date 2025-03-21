import { expect } from "chai";
import { cleanDeployment } from "./fixtures";

describe("Nodes", function () {
    it("should run test", async () => {
        const {nodes} = await cleanDeployment();
        expect(await nodes.REMOVE()).to.equal(5n);
    });
});
