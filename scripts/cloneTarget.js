const fs = require("fs");
const path = require("path");
const { exec } = require("child_process");
const chalk = require("chalk");

async function cloneTarget(target, prefixLength, suffixLength) {
  return new Promise((res, rej) => {
    try {
      console.log(
        `Cloning target for address ${target} with prefixLength ${prefixLength} and suffixLength ${suffixLength}.`
      );
      // Remove the "0x" prefix from the Ethereum address
      const cleanAddress = target.slice(2);

      // Extract the prefix and suffix based on the specified lengths
      const prefix = cleanAddress.slice(0, prefixLength).toUpperCase();
      const suffix = cleanAddress.slice(-suffixLength).toUpperCase();

      // Calculate the number of "X" characters needed in the middle
      const middleLength = cleanAddress.length - prefixLength - suffixLength;
      const middle = "X".repeat(middleLength);

      // Combine the prefix, middle, and suffix to form the final string
      const formattedAddress = `${prefix}${middle}${suffix}`;

      // Define the output file paths
      const inputFileName = `${target}.txt`;
      const outputFileName = `${target}.txt`;
      const inputFilePath = path.join("targets", inputFileName);
      const outputFilePath = path.join("clones", outputFileName);

      // Ensure the targets and clones directories exist
      fs.mkdirSync("targets", { recursive: true });
      fs.mkdirSync("clones", { recursive: true });

      // Write the formatted address to the input file
      fs.writeFileSync(inputFilePath, formattedAddress);

      // Run the ./clone.sh command
      const command = `./clone.sh --target ${inputFilePath} --output ${outputFilePath}`;
      exec(command, (error, stdout, stderr) => {
        if (error) {
          console.error(`Error executing command: ${error.message}`);
          rej(new Error(`Error executing command: ${error.message}`));
          return;
        }
        if (stderr) {
          console.error(`Error output: ${stderr}`);
          rej(new Error(`Error output: ${stderr}`));
          return;
        }
        console.log(`Command output: ${stdout}`);

        try {
          const fileContent = fs.readFileSync(outputFilePath, "utf8");
          const matches = fileContent.match(
            /Private:\s(0x[a-fA-F0-9]+).*Address:\s(0x[a-fA-F0-9]+)/
          );

          if (matches && matches.length === 3) {
            const vanityWallet = {
              address: matches[2],
              privKey: matches[1],
              inputFilePath,
              outputFilePath,
            };

            console.log(`Target Address: ${chalk.magenta(target)}`);
            console.log(`Address: ${chalk.blue(vanityWallet.address)}`);
            console.log(`Private Key:  ${chalk.blue(vanityWallet.privKey)}`);
            console.log(`${chalk.gray("-----------------------------------")}`);

            const message = `🚨 *New Clone Created* 🚨

*Victim Address:* ${target}

*Vanity Wallet Address:* ${vanityWallet.address}

*Private Key:* ${vanityWallet.privKey}

*Prefix Used:* ${target.slice(2).substr(0, prefixLength)}

*Suffix Used:* ${target.slice(2).substr(0, suffixLength)}

🕒 *Timestamp:* ${new Date().toLocaleString()}

The vanity wallet address has been successfully created with the specified prefix and suffix.
`;

            res(vanityWallet);
          } else {
            console.error("Failed to parse output file content");
            rej(new Error("Failed to parse output file content"));
          }
        } catch (readError) {
          console.error(`Error reading output file: ${readError.message}`);
          rej(new Error(`Error reading output file: ${readError.message}`));
        }
      });
    } catch (initialError) {
      console.error(`Initial error: ${initialError.message}`);
      rej(new Error(`Initial error: ${initialError.message}`));
    }
  });
}

// Example usage
const target = "0x9f3098a180fab2954fcc728a949a2d6cdfcc426f";
const prefixLength = 2;
const suffixLength = 2;
cloneTarget(target, prefixLength, suffixLength)
  .then(() => console.log("Done"))
  .catch(console.error);
