import { CopilotClient } from '@github/copilot-sdk';

async function main() {
  const client = new CopilotClient();
  await client.start();
  console.log('✅ Copilot SDK connected successfully!');
  await client.stop();
}

main().catch(console.error);
