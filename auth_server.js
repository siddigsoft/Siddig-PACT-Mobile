const express = require('express');
const cors = require('cors');
const app = express();
const port = 3000;

app.use(cors());

app.get('/', (req, res) => {
  const code = req.query.code;
  if (code) {
    // Close the window/redirect with the auth code
    res.send(`
      <html>
        <body>
          <script>
            window.opener.postMessage({ type: 'auth', code: '${code}' }, '*');
            window.close();
          </script>
        </body>
      </html>
    `);
  } else {
    res.send('No auth code received');
  }
});

app.listen(port, () => {
  console.log(`Auth callback server running at http://localhost:${port}`);
});