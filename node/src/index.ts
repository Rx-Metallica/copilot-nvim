import { CopilotClient, approveAll } from '@github/copilot-sdk';

const client = new CopilotClient();

function respond(data: object) {
  process.stdout.write(JSON.stringify(data) + '\n');
}

async function handleRequest(request: { id: string; type: string; data: any }) {
  const { id, type, data } = request;

  try {
    const session = await client.createSession({
      model: 'gpt-4.1',
      streaming: true,
      onPermissionRequest: approveAll,
    });

    let fullResponse = '';

    await new Promise<void>((resolve, reject) => {
      session.on('assistant.message_delta', (event) => {
        fullResponse += event.data.deltaContent;
      });
      session.on('session.idle', () => resolve());
      session.on('session.error', (event: any) => reject(new Error(event.data.message)));

      let prompt = '';
      if (type === 'complete') {
        prompt = `Complete this ${data.language} code:\n\n${data.prompt}`;
      } else if (type === 'chat') {
        prompt = data.message;
      } else if (type === 'review') {
        prompt = `Review this code and give feedback:\n\n${data.code}`;
      } else {
        reject(new Error(`Unknown type: ${type}`));
        return;
      }

      session.sendAndWait({ prompt });
    });

    respond({ id, success: true, result: fullResponse });

  } catch (err: any) {
    respond({ id, success: false, error: err.message });
  }
}

async function main() {
  await client.start();
  respond({ id: 'init', success: true, result: 'ready' });

  let buffer = '';
  process.stdin.setEncoding('utf8');

  process.stdin.on('data', (chunk) => {
    buffer += chunk;
    const lines = buffer.split('\n');
    buffer = lines.pop() ?? '';
    for (const line of lines) {
      if (line.trim()) {
        try {
          const request = JSON.parse(line);
          handleRequest(request);
        } catch {
          respond({ id: 'error', success: false, error: 'Invalid JSON' });
        }
      }
    }
  });

  process.stdin.on('close', async () => {
    await client.stop();
    process.exit(0);
  });
}

main().catch(console.error);