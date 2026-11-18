from http.server import BaseHTTPRequestHandler, HTTPServer
import json

class MockAI(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = json.loads(self.rfile.read(content_length))
        
        # Витягуємо текст запиту з повідомлення
        user_msg = ""
        if "messages" in post_data:
            user_msg = post_data["messages"][0]["content"]
        
        print(f"🤖 [MOCK AI] Отримано запит, довжина: {len(user_msg)}")
        
        # Визначаємо, що треба вставити
        # Якщо в запиті є "TEST_NEURO_FIX_OK" — повертаємо відповідний код
        if "TEST_NEURO_FIX_OK" in user_msg:
            fixed = '''async run(ctx) {
    console.log('TEST_NEURO_FIX_OK');
    const { provider, signClient, session, account, env } = ctx;
    return { success: true, note: 'TEST_NEURO_FIX_OK applied' };
}'''
        elif "MOCK AI" in user_msg:
            fixed = '''async run(ctx) {
    console.log('✅ MOCK AI виправила помилку!');
    return { success: true };
}'''
        else:
            fixed = '''async run(ctx) {
    console.log('✅ Neuro Department fix applied');
    return { success: true };
}'''
        
        fake_response = {"choices": [{"message": {"content": fixed}}]}
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(fake_response).encode())

print("🚀 Mock AI (Smart) на порту 11434...")
HTTPServer(('127.0.0.1', 11434), MockAI).serve_forever()
