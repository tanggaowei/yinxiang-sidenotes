/**
 * Yinxiang Biji (Evernote) Sync Worker
 * Lightweight Node.js helper invoked by the macOS Native App.
 */

const Evernote = require('evernote');

// Simple Markdown <-> ENML converter
function markdownToEnml(markdown) {
  if (!markdown) markdown = '';
  
  const lines = markdown.split('\n');
  let bodyHtml = '';

  for (let line of lines) {
    let trimmed = line.trim();
    if (!trimmed) {
      bodyHtml += '<div><br/></div>';
      continue;
    }

    // Checkbox / Todo
    if (trimmed.startsWith('- [x] ') || trimmed.startsWith('[x] ')) {
      const text = escapeXml(trimmed.replace(/^(\- )?\[x\] /, ''));
      bodyHtml += `<div><en-todo checked="true"/> ${text}</div>`;
      continue;
    }
    if (trimmed.startsWith('- [ ] ') || trimmed.startsWith('[ ] ')) {
      const text = escapeXml(trimmed.replace(/^(\- )?\[ \] /, ''));
      bodyHtml += `<div><en-todo checked="false"/> ${text}</div>`;
      continue;
    }

    // Headers
    if (trimmed.startsWith('### ')) {
      bodyHtml += `<h3>${escapeXml(trimmed.substring(4))}</h3>`;
      continue;
    }
    if (trimmed.startsWith('## ')) {
      bodyHtml += `<h2>${escapeXml(trimmed.substring(3))}</h2>`;
      continue;
    }
    if (trimmed.startsWith('# ')) {
      bodyHtml += `<h1>${escapeXml(trimmed.substring(2))}</h1>`;
      continue;
    }

    // Unordered list
    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      bodyHtml += `<div>• ${escapeXml(trimmed.substring(2))}</div>`;
      continue;
    }

    // Regular line
    bodyHtml += `<div>${escapeXml(trimmed)}</div>`;
  }

  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">
<en-note>${bodyHtml}</en-note>`;
}

function enmlToMarkdown(enml) {
  if (!enml) return '';

  let text = enml;
  // Replace XML headers
  text = text.replace(/<\?xml[\s\S]*?\?>/gi, '');
  text = text.replace(/<!DOCTYPE[\s\S]*?>/gi, '');
  text = text.replace(/<en-note[\s\S]*?>/gi, '');
  text = text.replace(/<\/en-note>/gi, '');

  // Replace en-todo
  text = text.replace(/<en-todo\s+checked="true"\s*\/?>/gi, '- [x] ');
  text = text.replace(/<en-todo\s+checked="false"\s*\/?>/gi, '- [ ] ');
  text = text.replace(/<en-todo\s*\/?>/gi, '- [ ] ');

  // Headers
  text = text.replace(/<h1>([\s\S]*?)<\/h1>/gi, '# $1\n');
  text = text.replace(/<h2>([\s\S]*?)<\/h2>/gi, '## $1\n');
  text = text.replace(/<h3>([\s\S]*?)<\/h3>/gi, '### $1\n');

  // Paragraphs & Divs
  text = text.replace(/<div>([\s\S]*?)<\/div>/gi, '$1\n');
  text = text.replace(/<p>([\s\S]*?)<\/p>/gi, '$1\n\n');
  text = text.replace(/<br\s*\/?>/gi, '\n');
  text = text.replace(/<li>([\s\S]*?)<\/li>/gi, '- $1\n');

  // Strip remaining HTML tags
  text = text.replace(/<[^>]+>/g, '');

  // Unescape XML entities
  text = text.replace(/&amp;/g, '&')
             .replace(/&lt;/g, '<')
             .replace(/&gt;/g, '>')
             .replace(/&quot;/g, '"')
             .replace(/&apos;/g, "'")
             .replace(/&nbsp;/g, ' ');

  return text.trim();
}

function escapeXml(unsafe) {
  return (unsafe || '').replace(/[<>&'"]/g, function (c) {
    switch (c) {
      case '<': return '&lt;';
      case '>': return '&gt;';
      case '&': return '&amp;';
      case '\'': return '&apos;';
      case '"': return '&quot;';
    }
  });
}

function getClient(token, china) {
  const isChina = (china === true || china === 'true');
  return new Evernote.Client({
    token: token,
    sandbox: false,
    china: isChina,
    serviceHost: isChina ? 'app.yinxiang.com' : 'www.evernote.com'
  });
}

async function handleAction(action, args) {
  const { token, china } = args;
  if (!token) {
    throw new Error('Token is required');
  }

  const client = getClient(token, china);

  switch (action) {
    case 'test-connection': {
      const userStore = client.getUserStore();
      const user = await userStore.getUser();
      return {
        success: true,
        user: {
          id: user.id,
          username: user.username,
          name: user.name || user.username
        }
      };
    }

    case 'list-notebooks': {
      const noteStore = client.getNoteStore();
      const notebooks = await noteStore.listNotebooks();
      return {
        success: true,
        notebooks: (notebooks || []).map(nb => ({
          guid: nb.guid,
          name: nb.name,
          defaultNotebook: !!nb.defaultNotebook
        }))
      };
    }

    case 'get-or-create-default': {
      const name = args.name || 'SideNotes';
      const noteStore = client.getNoteStore();
      const notebooks = await noteStore.listNotebooks();
      let found = (notebooks || []).find(n => n.name === name);
      if (found) {
        return {
          success: true,
          notebook: {
            guid: found.guid,
            name: found.name,
            defaultNotebook: !!found.defaultNotebook
          },
          created: false
        };
      }
      // Create new notebook
      const newNb = await noteStore.createNotebook({ name: name });
      return {
        success: true,
        notebook: {
          guid: newNb.guid,
          name: newNb.name,
          defaultNotebook: false
        },
        created: true
      };
    }

    case 'create-notebook': {
      const name = args.name;
      if (!name) throw new Error('Notebook name is required');
      const noteStore = client.getNoteStore();
      const newNb = await noteStore.createNotebook({ name: name });
      return {
        success: true,
        notebook: {
          guid: newNb.guid,
          name: newNb.name,
          defaultNotebook: false
        }
      };
    }

    case 'fetch-notes': {
      const notebookGuid = args.notebookGuid;
      const noteStore = client.getNoteStore();
      const filter = new Evernote.NoteStore.NoteFilter({
        notebookGuid: notebookGuid,
        order: Evernote.Types.NoteSortOrder.UPDATED,
        ascending: false
      });
      const spec = new Evernote.NoteStore.NotesMetadataResultSpec({
        includeTitle: true,
        includeUpdated: true,
        includeCreated: true
      });

      const metaList = await noteStore.findNotesMetadata(filter, 0, 50, spec);
      const notes = [];

      for (const meta of (metaList.notes || [])) {
        try {
          const fullNote = await noteStore.getNote(meta.guid, true, false, false, false);
          notes.push({
            guid: fullNote.guid,
            title: fullNote.title || '无标题笔记',
            content: enmlToMarkdown(fullNote.content),
            updated: fullNote.updated,
            created: fullNote.created,
            notebookGuid: fullNote.notebookGuid
          });
        } catch (e) {
          notes.push({
            guid: meta.guid,
            title: meta.title || '无标题笔记',
            content: '',
            updated: meta.updated,
            created: meta.created,
            notebookGuid: notebookGuid
          });
        }
      }

      return {
        success: true,
        notes: notes
      };
    }

    case 'save-note': {
      const noteStore = client.getNoteStore();
      const { guid, notebookGuid, title, content } = args;

      const note = new Evernote.Types.Note();
      note.title = (title || '无标题笔记').slice(0, 255);
      note.content = markdownToEnml(content || '');
      if (notebookGuid) {
        note.notebookGuid = notebookGuid;
      }

      let result;
      // If guid is a 36-char Evernote GUID
      if (guid && /^[0-9a-fA-F-]{32,36}$/.test(guid)) {
        note.guid = guid;
        result = await noteStore.updateNote(note);
      } else {
        result = await noteStore.createNote(note);
      }

      return {
        success: true,
        note: {
          guid: result.guid,
          title: result.title,
          content: content,
          updated: result.updated,
          notebookGuid: result.notebookGuid
        }
      };
    }

    case 'delete-note': {
      const noteStore = client.getNoteStore();
      const { guid } = args;
      if (!guid) throw new Error('Note guid is required');
      await noteStore.deleteNote(guid);
      return { success: true, guid: guid };
    }

    default:
      throw new Error(`Unknown action: ${action}`);
  }
}

// CLI entry point
async function main() {
  const args = process.argv.slice(2);
  const action = args[0];
  const payloadStr = args[1];

  if (!action) {
    console.error(JSON.stringify({ success: false, error: 'No action provided' }));
    process.exit(1);
  }

  let payload = {};
  if (payloadStr) {
    try {
      payload = JSON.parse(payloadStr);
    } catch (e) {
      console.error(JSON.stringify({ success: false, error: 'Invalid JSON payload' }));
      process.exit(1);
    }
  }

  try {
    const result = await handleAction(action, payload);
    console.log(JSON.stringify(result));
    process.exit(0);
  } catch (err) {
    let msg = err.message;
    if (!msg && err.errorCode !== undefined) {
      msg = `EDAM Error Code: ${err.errorCode}` + (err.parameter ? ` (${err.parameter})` : '');
    }
    if (!msg) {
      try {
        msg = JSON.stringify(err);
      } catch (e) {
        msg = String(err);
      }
    }
    console.log(JSON.stringify({
      success: false,
      error: msg
    }));
    process.exit(1);
  }
}

main();
