// Shows the newest version and links each button straight to that version's file
// (e.g. Snapperr-Setup-1.1.0.exe). Without this script the buttons open the GitHub releases page.
fetch('https://api.github.com/repos/simplyzubair/Snapperr/releases/latest')
  .then((r) => (r.ok ? r.json() : null))
  .then((data) => {
    if (!data || !data.tag_name) return;
    const version = data.tag_name.replace(/^v/, '');
    document.getElementById('version').textContent =
      `Latest version ${version}. Snap any window into place with your keyboard. Free for Windows and Mac.`;
    const assets = Array.isArray(data.assets) ? data.assets : [];
    const link = (id, test) => {
      const asset = assets.find((a) => test.test(a.name || ''));
      const url = (asset && asset.browser_download_url) || '';
      if (url.startsWith('https://github.com/simplyzubair/Snapperr/releases/download/')) document.getElementById(id).href = url;
    };
    link('download-windows', /^Snapperr-Setup-[\d.]+\.exe$/);
    link('download-mac', /^Snapperr-[\d.]+-mac\.dmg$/);
  })
  .catch(() => {});
