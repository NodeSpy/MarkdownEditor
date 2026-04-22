/* ============================================================
   MarkdownEditor – True Inline WYSIWYG Engine
   Always shows rendered rich HTML. Markdown syntax typed by the
   user is detected and transformed into formatted elements
   instantly. Turndown.js converts HTML back to Markdown for
   saving/export.
   ============================================================ */

(function() {
    'use strict';

    // ---- State ----
    const state = {
        markdown: '',
        mode: 'preview',        // 'preview' | 'source'
        focusMode: false,
        typewriterMode: false,
        fontSize: 16,
        theme: 'light',
        dirty: false,
        syncTimeout: null,
        processing: false
    };

    // ---- DOM ----
    const editorContainer = document.getElementById('editor-container');
    const editor = document.getElementById('editor');

    // ============================================================
    // markdown-it (Markdown -> HTML, used for initial load & source toggle)
    // ============================================================

    const md = window.markdownit({
        html: true,
        linkify: true,
        typographer: true,
        breaks: false,
        highlight: function(str, lang) {
            if (lang && hljs.getLanguage(lang)) {
                try {
                    const highlighted = hljs.highlight(str, { language: lang, ignoreIllegals: true }).value;
                    return '<pre class="hljs"><code>' +
                           '<span class="lang-label">' + lang + '</span>' +
                           highlighted + '</code></pre>';
                } catch (_) {}
            }
            return '<pre class="hljs"><code>' + md.utils.escapeHtml(str) + '</code></pre>';
        }
    });
    md.use(window.markdownitTaskLists, { enabled: true, label: true });

    // KaTeX math plugin
    (function mathPlugin(md) {
        md.inline.ruler.after('escape', 'math_inline', function(st, silent) {
            if (st.src[st.pos] !== '$' || st.src[st.pos + 1] === '$') return false;
            const start = st.pos + 1;
            if (start >= st.src.length) return false;
            var firstChar = st.src[start];
            // Reject if content starts with a digit (currency like $5,003) or whitespace
            if (/[\d\s]/.test(firstChar)) return false;
            var end = start;
            while (end < st.src.length) {
                if (st.src[end] === '\n') return false; // no newline spanning
                if (st.src[end] === '$') break;
                if (st.src[end] === '\\') end++;
                end++;
            }
            if (end >= st.src.length) return false;
            // Reject empty content or content ending with whitespace
            if (end === start) return false;
            if (/\s/.test(st.src[end - 1])) return false;
            if (!silent) { var t = st.push('math_inline', 'math', 0); t.content = st.src.slice(start, end); t.markup = '$'; }
            st.pos = end + 1;
            return true;
        });
        md.renderer.rules.math_inline = function(tokens, idx) {
            try { return katex.renderToString(tokens[idx].content, { throwOnError: false, displayMode: false }); }
            catch(e) { return '<span style="color:red">' + md.utils.escapeHtml(tokens[idx].content) + '</span>'; }
        };
        md.block.ruler.after('blockquote', 'math_block', function(st, startLine, endLine, silent) {
            const sp = st.bMarks[startLine] + st.tShift[startLine];
            if (st.src.slice(sp, sp + 2) !== '$$') return false;
            let nl = startLine, found = false;
            while (++nl < endLine) { const p = st.bMarks[nl] + st.tShift[nl]; if (st.src.slice(p, p + 2) === '$$') { found = true; break; } }
            if (!found) return false;
            if (silent) return true;
            const t = st.push('math_block', 'math', 0);
            t.content = st.src.split('\n').slice(startLine + 1, nl).join('\n').trim();
            t.markup = '$$'; t.map = [startLine, nl + 1]; st.line = nl + 1;
            return true;
        });
        md.renderer.rules.math_block = function(tokens, idx) {
            try { return '<div class="katex-display">' + katex.renderToString(tokens[idx].content, { throwOnError: false, displayMode: true }) + '</div>'; }
            catch(e) { return '<div style="color:red">' + md.utils.escapeHtml(tokens[idx].content) + '</div>'; }
        };
    })(md);

    // ============================================================
    // Turndown (HTML -> Markdown)
    // ============================================================

    let turndownService = null;
    function getTurndown() {
        if (turndownService) return turndownService;
        turndownService = new TurndownService({
            headingStyle: 'atx',
            hr: '---',
            bulletListMarker: '-',
            codeBlockStyle: 'fenced',
            fence: '```',
            emDelimiter: '*',
            strongDelimiter: '**',
            linkStyle: 'inlined'
        });
        if (window.turndownPluginGfm) {
            turndownService.use(turndownPluginGfm.gfm);
        }
        // Preserve KaTeX display blocks
        turndownService.addRule('katexDisplay', {
            filter: function(node) {
                return node.classList && node.classList.contains('katex-display');
            },
            replacement: function(content, node) {
                const math = node.querySelector('annotation[encoding="application/x-tex"]');
                if (math) return '\n\n$$\n' + math.textContent + '\n$$\n\n';
                return '\n\n$$\n' + content.trim() + '\n$$\n\n';
            }
        });
        // Preserve inline KaTeX
        turndownService.addRule('katexInline', {
            filter: function(node) {
                return node.classList && node.classList.contains('katex');
            },
            replacement: function(content, node) {
                const math = node.querySelector('annotation[encoding="application/x-tex"]');
                if (math) return '$' + math.textContent + '$';
                return '$' + content.trim() + '$';
            }
        });
        // Preserve mermaid
        turndownService.addRule('mermaid', {
            filter: function(node) {
                return node.classList && node.classList.contains('mermaid');
            },
            replacement: function(content, node) {
                const svg = node.querySelector('svg');
                const code = node.getAttribute('data-mermaid-src') || content.trim();
                return '\n\n```mermaid\n' + code + '\n```\n\n';
            }
        });
        return turndownService;
    }

    function htmlToMarkdown() {
        try {
            return getTurndown().turndown(editor.innerHTML);
        } catch(e) {
            console.warn('Turndown error:', e);
            return editor.textContent;
        }
    }

    // ============================================================
    // Rendering (Markdown -> HTML, for initial load)
    // ============================================================

    function renderFullHTML(markdownText) {
        editor.innerHTML = md.render(markdownText);
        postRenderTasks();
    }

    function postRenderTasks() {
        renderMermaidDiagrams();
        extractHeadings();
        updateWordCount();
        bindTaskCheckboxes();
    }

    function renderMermaidDiagrams() {
        const blocks = editor.querySelectorAll('pre code.language-mermaid');
        blocks.forEach(function(block) {
            const pre = block.parentElement;
            const code = block.textContent;
            const container = document.createElement('div');
            container.className = 'mermaid';
            container.setAttribute('data-mermaid-src', code);
            container.textContent = code;
            pre.replaceWith(container);
        });
        if (typeof mermaid !== 'undefined') {
            try { mermaid.run({ querySelector: '.mermaid' }); } catch(e) {}
        }
    }

    // ============================================================
    // Sync: HTML -> Markdown (debounced)
    // ============================================================

    function scheduleSyncMarkdown() {
        clearTimeout(state.syncTimeout);
        state.syncTimeout = setTimeout(doSyncMarkdown, 400);
    }

    function doSyncMarkdown() {
        if (state.mode !== 'preview') return;
        state.markdown = htmlToMarkdown();
        state.dirty = true;
        postMessage('contentChanged', { content: state.markdown });
        extractHeadings();
        updateWordCount();
    }

    // ============================================================
    // Inline Pattern Detection
    // ============================================================

    function processInlinePatterns() {
        if (state.processing || state.mode !== 'preview') return;
        state.processing = true;

        const sel = window.getSelection();
        if (!sel.rangeCount || !sel.isCollapsed) { state.processing = false; return; }

        let textNode = sel.anchorNode;
        if (!textNode || textNode.nodeType !== Node.TEXT_NODE) { state.processing = false; return; }
        // Don't process inside code or pre
        if (isInsideTag(textNode, ['CODE', 'PRE'])) { state.processing = false; return; }

        const text = textNode.textContent;
        const cursorPos = sel.anchorOffset;

        // Only scan up to cursor position
        const before = text.slice(0, cursorPos);

        // Check patterns in order of specificity
        if (tryInlineReplace(textNode, before, cursorPos, /`([^`]+)`$/, 'CODE')) { state.processing = false; return; }
        if (tryInlineReplace(textNode, before, cursorPos, /\*\*(.+?)\*\*$/, 'STRONG')) { state.processing = false; return; }
        if (tryInlineReplace(textNode, before, cursorPos, /(?<!\*)\*([^*]+)\*$/, 'EM')) { state.processing = false; return; }
        if (tryInlineReplace(textNode, before, cursorPos, /~~(.+?)~~$/, 'DEL')) { state.processing = false; return; }
        if (tryLinkReplace(textNode, before, cursorPos)) { state.processing = false; return; }
        if (tryImageReplace(textNode, before, cursorPos)) { state.processing = false; return; }

        state.processing = false;
    }

    function tryInlineReplace(textNode, before, cursorPos, regex, tag) {
        const match = before.match(regex);
        if (!match) return false;

        const fullMatch = match[0];
        const innerText = match[1];
        if (!innerText || !innerText.trim()) return false;

        const matchStart = before.length - fullMatch.length;
        const matchEnd = before.length;

        const el = document.createElement(tag);
        el.textContent = innerText;

        replaceTextRange(textNode, matchStart, matchEnd, el);
        placeCursorAfter(el);
        return true;
    }

    function tryLinkReplace(textNode, before, cursorPos) {
        const match = before.match(/\[([^\]]+)\]\(([^)]+)\)$/);
        if (!match) return false;

        const fullMatch = match[0];
        const linkText = match[1];
        const url = match[2];
        const matchStart = before.length - fullMatch.length;

        const a = document.createElement('a');
        a.href = url;
        a.textContent = linkText;
        a.setAttribute('target', '_blank');

        replaceTextRange(textNode, matchStart, before.length, a);
        placeCursorAfter(a);
        return true;
    }

    function tryImageReplace(textNode, before, cursorPos) {
        const match = before.match(/!\[([^\]]*)\]\(([^)]+)\)$/);
        if (!match) return false;

        const fullMatch = match[0];
        const alt = match[1];
        const src = match[2];
        const matchStart = before.length - fullMatch.length;

        const img = document.createElement('img');
        img.src = src;
        img.alt = alt;

        replaceTextRange(textNode, matchStart, before.length, img);
        placeCursorAfter(img);
        return true;
    }

    // ============================================================
    // Block Pattern Detection
    // ============================================================

    function processBlockPatterns(e) {
        if (state.mode !== 'preview') return false;

        const sel = window.getSelection();
        if (!sel.rangeCount) return false;

        const block = getContainingBlock(sel.anchorNode);
        if (!block) return false;

        // Don't transform inside pre/code
        if (isInsideTag(sel.anchorNode, ['PRE', 'CODE'])) return false;
        // Don't transform inside list items (they're already in a list)
        if (e.key === ' ' && isInsideTag(sel.anchorNode, ['LI'])) return false;

        const text = block.textContent;

        if (e.key === ' ') {
            // Heading: # through ######
            const headingMatch = text.match(/^(#{1,6})$/);
            if (headingMatch) {
                e.preventDefault();
                const level = headingMatch[1].length;
                const h = document.createElement('h' + level);
                h.innerHTML = '<br>';
                block.replaceWith(h);
                placeCursorInside(h);
                scheduleSyncMarkdown();
                return true;
            }

            // Unordered list: - or *
            if (text === '-' || text === '*') {
                e.preventDefault();
                const ul = document.createElement('ul');
                const li = document.createElement('li');
                li.innerHTML = '<br>';
                ul.appendChild(li);
                block.replaceWith(ul);
                placeCursorInside(li);
                scheduleSyncMarkdown();
                return true;
            }

            // Ordered list: 1.
            if (/^\d+\.$/.test(text)) {
                e.preventDefault();
                const ol = document.createElement('ol');
                const li = document.createElement('li');
                li.innerHTML = '<br>';
                ol.appendChild(li);
                block.replaceWith(ol);
                placeCursorInside(li);
                scheduleSyncMarkdown();
                return true;
            }

            // Blockquote: >
            if (text === '>') {
                e.preventDefault();
                const bq = document.createElement('blockquote');
                const p = document.createElement('p');
                p.innerHTML = '<br>';
                bq.appendChild(p);
                block.replaceWith(bq);
                placeCursorInside(p);
                scheduleSyncMarkdown();
                return true;
            }

            // Task list: - [ ] or - [x]
            if (text === '- [ ]' || text === '- [x]') {
                e.preventDefault();
                const checked = text === '- [x]';
                const ul = document.createElement('ul');
                ul.className = 'task-list';
                const li = document.createElement('li');
                li.className = 'task-list-item';
                const cb = document.createElement('input');
                cb.type = 'checkbox';
                cb.checked = checked;
                li.appendChild(cb);
                li.appendChild(document.createTextNode(' '));
                ul.appendChild(li);
                block.replaceWith(ul);
                placeCursorAtEnd(li);
                scheduleSyncMarkdown();
                return true;
            }
        }

        if (e.key === 'Enter') {
            // Horizontal rule: --- or ***
            if (/^(-{3,}|\*{3,})$/.test(text.trim())) {
                e.preventDefault();
                const hr = document.createElement('hr');
                const p = document.createElement('p');
                p.innerHTML = '<br>';
                block.replaceWith(hr);
                hr.after(p);
                placeCursorInside(p);
                scheduleSyncMarkdown();
                return true;
            }

            // Code block: ```
            const fenceMatch = text.trim().match(/^`{3,}(.*)$/);
            if (fenceMatch) {
                e.preventDefault();
                const lang = fenceMatch[1].trim();
                const pre = document.createElement('pre');
                const code = document.createElement('code');
                if (lang) {
                    code.className = 'language-' + lang;
                    const label = document.createElement('span');
                    label.className = 'lang-label';
                    label.textContent = lang;
                    pre.appendChild(label);
                }
                code.innerHTML = '<br>';
                pre.appendChild(code);
                const afterP = document.createElement('p');
                afterP.innerHTML = '<br>';
                block.replaceWith(pre);
                pre.after(afterP);
                placeCursorInside(code);
                scheduleSyncMarkdown();
                return true;
            }
        }

        return false;
    }

    // ============================================================
    // List Continuation
    // ============================================================

    function handleListContinuation(e) {
        if (e.key !== 'Enter' || state.mode !== 'preview') return false;

        const sel = window.getSelection();
        if (!sel.rangeCount) return false;

        const li = getClosestElement(sel.anchorNode, 'LI');
        if (!li) return false;

        e.preventDefault();

        const list = li.parentElement; // UL or OL
        const isEmpty = !li.textContent.trim() ||
                        (li.textContent.trim() === '' && li.querySelector('input[type="checkbox"]') && !li.textContent.replace(/\s/g, ''));

        if (isEmpty) {
            // Empty item -> break out of list
            li.remove();
            if (list.children.length === 0) {
                const p = document.createElement('p');
                p.innerHTML = '<br>';
                list.replaceWith(p);
                placeCursorInside(p);
            } else {
                const p = document.createElement('p');
                p.innerHTML = '<br>';
                list.after(p);
                placeCursorInside(p);
            }
        } else {
            // Non-empty -> continue list
            const newLi = document.createElement('li');

            // If task list, add checkbox
            if (li.classList.contains('task-list-item') || li.querySelector('input[type="checkbox"]')) {
                newLi.className = 'task-list-item';
                const cb = document.createElement('input');
                cb.type = 'checkbox';
                newLi.appendChild(cb);
                newLi.appendChild(document.createTextNode(' '));
            } else {
                newLi.innerHTML = '<br>';
            }

            li.after(newLi);
            placeCursorAtEnd(newLi);
        }

        scheduleSyncMarkdown();
        return true;
    }

    // ============================================================
    // DOM Helpers
    // ============================================================

    function replaceTextRange(textNode, start, end, newElement) {
        const parent = textNode.parentNode;
        const beforeText = textNode.textContent.slice(0, start);
        const afterText = textNode.textContent.slice(end);

        const frag = document.createDocumentFragment();
        if (beforeText) frag.appendChild(document.createTextNode(beforeText));
        frag.appendChild(newElement);
        if (afterText) frag.appendChild(document.createTextNode(afterText));

        parent.replaceChild(frag, textNode);
    }

    function placeCursorAfter(element) {
        const sel = window.getSelection();
        const range = document.createRange();
        const next = element.nextSibling;
        if (next && next.nodeType === Node.TEXT_NODE) {
            range.setStart(next, 0);
        } else {
            // Insert a zero-width space after so cursor has somewhere to go
            const space = document.createTextNode('\u200B');
            element.parentNode.insertBefore(space, element.nextSibling);
            range.setStart(space, 1);
        }
        range.collapse(true);
        sel.removeAllRanges();
        sel.addRange(range);
    }

    function placeCursorInside(element) {
        const sel = window.getSelection();
        const range = document.createRange();
        range.selectNodeContents(element);
        range.collapse(true);
        sel.removeAllRanges();
        sel.addRange(range);
    }

    function placeCursorAtEnd(element) {
        const sel = window.getSelection();
        const range = document.createRange();
        range.selectNodeContents(element);
        range.collapse(false);
        sel.removeAllRanges();
        sel.addRange(range);
    }

    function getContainingBlock(node) {
        const blockTags = ['P', 'DIV', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6',
                           'LI', 'BLOCKQUOTE', 'PRE', 'HR', 'TABLE'];
        let el = node;
        while (el && el !== editor) {
            if (el.nodeType === Node.ELEMENT_NODE && blockTags.includes(el.tagName)) {
                return el;
            }
            el = el.parentNode;
        }
        // If it's a direct child text node of editor, wrap it
        if (node.parentNode === editor) {
            return node.nodeType === Node.ELEMENT_NODE ? node : null;
        }
        return null;
    }

    function getClosestElement(node, tagName) {
        let el = node;
        while (el && el !== editor) {
            if (el.nodeType === Node.ELEMENT_NODE && el.tagName === tagName) return el;
            el = el.parentNode;
        }
        return null;
    }

    function isInsideTag(node, tagNames) {
        let el = node;
        while (el && el !== editor) {
            if (el.nodeType === Node.ELEMENT_NODE && tagNames.includes(el.tagName)) return true;
            el = el.parentNode;
        }
        return false;
    }

    // ============================================================
    // Keyboard Shortcuts
    // ============================================================

    function handleKeydown(e) {
        // List continuation takes priority
        if (handleListContinuation(e)) return;

        // Block patterns on Space and Enter
        if (e.key === ' ' || e.key === 'Enter') {
            if (processBlockPatterns(e)) return;
        }

        // Handle Enter inside code blocks
        if (e.key === 'Enter' && isInsideTag(getSelection().anchorNode, ['PRE', 'CODE'])) {
            e.preventDefault();
            document.execCommand('insertText', false, '\n');
            return;
        }

        // Cmd/Ctrl shortcuts
        if (e.metaKey || e.ctrlKey) {
            switch(e.key) {
                case 'b':
                    e.preventDefault();
                    document.execCommand('bold', false, null);
                    scheduleSyncMarkdown();
                    return;
                case 'i':
                    e.preventDefault();
                    document.execCommand('italic', false, null);
                    scheduleSyncMarkdown();
                    return;
                case 'k':
                    e.preventDefault();
                    insertLinkPrompt();
                    return;
                case 's':
                    e.preventDefault();
                    postMessage('save', {});
                    return;
            }
            if (e.shiftKey && e.key === 'x') {
                e.preventDefault();
                document.execCommand('strikeThrough', false, null);
                scheduleSyncMarkdown();
                return;
            }
        }

        // Typewriter scroll
        if (state.typewriterMode) {
            setTimeout(scrollToActiveLine, 50);
        }
    }

    function insertLinkPrompt() {
        const sel = window.getSelection();
        if (!sel.rangeCount) return;
        const text = sel.toString() || 'link';
        document.execCommand('insertHTML', false,
            '<a href="url" target="_blank">' + escapeHTML(text) + '</a>');
        scheduleSyncMarkdown();
    }

    function escapeHTML(text) {
        const d = document.createElement('div');
        d.textContent = text;
        return d.innerHTML;
    }

    // ============================================================
    // Input Handler
    // ============================================================

    function handleInput(e) {
        if (state.mode !== 'preview') {
            // In source mode, just sync text
            state.markdown = editor.textContent;
            postMessage('contentChanged', { content: state.markdown });
            debounceExtractMeta();
            return;
        }

        // Try inline pattern detection
        processInlinePatterns();

        // Sync markdown
        scheduleSyncMarkdown();
    }

    let metaTimeout = null;
    function debounceExtractMeta() {
        clearTimeout(metaTimeout);
        metaTimeout = setTimeout(function() {
            extractHeadingsFromMarkdown();
            updateWordCount();
        }, 300);
    }

    // ============================================================
    // Focus Mode
    // ============================================================

    function updateFocusMode() {
        if (!state.focusMode) return;
        const sel = window.getSelection();
        if (!sel.rangeCount) return;
        let activeEl = sel.anchorNode;
        while (activeEl && activeEl.parentElement !== editor) activeEl = activeEl.parentElement;
        const children = editor.children;
        for (let i = 0; i < children.length; i++) {
            children[i].classList.toggle('focused', children[i] === activeEl);
        }
    }

    function toggleFocusMode(enabled) {
        state.focusMode = enabled;
        document.body.classList.toggle('focus-mode', enabled);
        if (enabled) updateFocusMode();
    }

    // ============================================================
    // Typewriter Mode
    // ============================================================

    function toggleTypewriterMode(enabled) {
        state.typewriterMode = enabled;
        document.body.classList.toggle('typewriter-mode', enabled);
        if (enabled) scrollToActiveLine();
    }

    function scrollToActiveLine() {
        const sel = window.getSelection();
        if (!sel.rangeCount) return;
        const range = sel.getRangeAt(0);
        const rect = range.getBoundingClientRect();
        const containerRect = editorContainer.getBoundingClientRect();
        const scrollTarget = editorContainer.scrollTop + rect.top - containerRect.top - containerRect.height / 2;
        editorContainer.scrollTo({ top: scrollTarget, behavior: 'smooth' });
    }

    // ============================================================
    // Headings
    // ============================================================

    function extractHeadings() {
        const headings = [];
        editor.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach(function(el, idx) {
            headings.push({ level: parseInt(el.tagName[1]), text: el.textContent, id: 'heading-' + idx });
            el.id = 'heading-' + idx;
        });
        postMessage('headings', { headings: headings });
    }

    function extractHeadingsFromMarkdown() {
        const headings = [];
        let idx = 0;
        state.markdown.split('\n').forEach(function(line) {
            const m = line.match(/^(#{1,6})\s+(.+)/);
            if (m) { headings.push({ level: m[1].length, text: m[2].replace(/[#*_`~\[\]]/g, ''), id: 'heading-' + idx }); idx++; }
        });
        postMessage('headings', { headings: headings });
    }

    // ============================================================
    // Word Count
    // ============================================================

    function updateWordCount() {
        const text = state.mode === 'preview' ? editor.textContent : state.markdown;
        const words = text.trim() ? text.trim().split(/\s+/).length : 0;
        const chars = text.length;
        const lines = text ? text.split('\n').length : 0;
        postMessage('wordCount', { words: words, characters: chars, lines: lines, readingTime: Math.max(1, Math.ceil(words / 250)) });
    }

    // ============================================================
    // Task Checkboxes
    // ============================================================

    function bindTaskCheckboxes() {
        editor.querySelectorAll('input[type="checkbox"]').forEach(function(cb) {
            cb.addEventListener('change', function() { scheduleSyncMarkdown(); });
        });
    }

    // ============================================================
    // Scroll to Heading
    // ============================================================

    function scrollToHeading(id) {
        const el = document.getElementById(id);
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }

    // ============================================================
    // Theme & Font Size
    // ============================================================

    function setTheme(theme) {
        state.theme = theme;
        document.documentElement.setAttribute('data-theme', theme);
        if (typeof mermaid !== 'undefined') {
            mermaid.initialize({ startOnLoad: false, theme: theme === 'dark' ? 'dark' : 'default', securityLevel: 'loose' });
        }
    }

    function setFontSize(size) {
        state.fontSize = size;
        document.documentElement.style.setProperty('--font-size', size + 'px');
    }

    // ============================================================
    // Mode Switching
    // ============================================================

    function switchToPreview() {
        state.mode = 'preview';
        document.body.classList.remove('source-mode');
        // Re-render from markdown
        renderFullHTML(state.markdown);
        editor.setAttribute('contenteditable', 'true');
        editor.focus();
    }

    function switchToSource() {
        // Capture current HTML as markdown
        state.markdown = htmlToMarkdown();
        state.mode = 'source';
        document.body.classList.add('source-mode');
        editor.textContent = state.markdown;
        editor.setAttribute('contenteditable', 'true');
        editor.focus();
    }

    // ============================================================
    // Click Handler
    // ============================================================

    editor.addEventListener('click', function(e) {
        if (e.target.tagName === 'A') {
            if (e.metaKey || e.ctrlKey) {
                e.preventDefault();
                postMessage('openLink', { url: e.target.href });
            }
        }
    });

    // ============================================================
    // Swift Bridge
    // ============================================================

    function postMessage(type, data) {
        try {
            window.webkit.messageHandlers.editorBridge.postMessage(JSON.stringify({ type: type, data: data }));
        } catch(e) {
            console.log('Bridge:', type, data);
        }
    }

    // ============================================================
    // Public API
    // ============================================================

    window.editorAPI = {
        setContent: function(markdownText) {
            state.markdown = markdownText || '';
            if (state.mode === 'source') {
                editor.textContent = state.markdown;
            } else {
                renderFullHTML(state.markdown);
                // Place cursor at end
                const range = document.createRange();
                range.selectNodeContents(editor);
                range.collapse(false);
                const sel = window.getSelection();
                sel.removeAllRanges();
                sel.addRange(range);
            }
        },

        getContent: function() {
            if (state.mode === 'preview') {
                state.markdown = htmlToMarkdown();
            } else {
                state.markdown = editor.textContent;
            }
            return state.markdown;
        },

        getHTML: function() {
            if (state.mode === 'source') {
                return md.render(state.markdown);
            }
            return editor.innerHTML;
        },

        toggleMode: function() {
            if (state.mode === 'preview') switchToSource();
            else switchToPreview();
            postMessage('modeChanged', { mode: state.mode });
        },

        setMode: function(mode) {
            if (mode === 'source' && state.mode !== 'source') switchToSource();
            else if (mode === 'preview' && state.mode !== 'preview') switchToPreview();
        },

        setTheme: setTheme,
        setFontSize: setFontSize,
        toggleFocusMode: function() { toggleFocusMode(!state.focusMode); },
        toggleTypewriterMode: function() { toggleTypewriterMode(!state.typewriterMode); },
        setFocusMode: function(enabled) { toggleFocusMode(enabled); },
        setTypewriterMode: function(enabled) { toggleTypewriterMode(enabled); },
        scrollToHeading: scrollToHeading,

        applyFormatting: function(format) {
            if (state.mode === 'source') return; // No rich formatting in source mode
            switch(format) {
                case 'bold': document.execCommand('bold', false, null); break;
                case 'italic': document.execCommand('italic', false, null); break;
                case 'strikethrough': document.execCommand('strikeThrough', false, null); break;
                case 'code':
                    var sel = window.getSelection();
                    if (sel.rangeCount) {
                        var text = sel.toString() || 'code';
                        document.execCommand('insertHTML', false, '<code>' + escapeHTML(text) + '</code>');
                    }
                    break;
                case 'link': insertLinkPrompt(); break;
                case 'h1': document.execCommand('formatBlock', false, 'h1'); break;
                case 'h2': document.execCommand('formatBlock', false, 'h2'); break;
                case 'h3': document.execCommand('formatBlock', false, 'h3'); break;
                case 'h4': document.execCommand('formatBlock', false, 'h4'); break;
                case 'quote': document.execCommand('formatBlock', false, 'blockquote'); break;
                case 'ul': document.execCommand('insertUnorderedList', false, null); break;
                case 'ol': document.execCommand('insertOrderedList', false, null); break;
                case 'task':
                    document.execCommand('insertHTML', false,
                        '<ul class="task-list"><li class="task-list-item"><input type="checkbox"> </li></ul>');
                    break;
                case 'hr': document.execCommand('insertHorizontalRule', false, null); break;
                case 'codeblock':
                    document.execCommand('insertHTML', false,
                        '<pre><code><br></code></pre><p><br></p>');
                    break;
                case 'table':
                    document.execCommand('insertHTML', false,
                        '<table><thead><tr><th>Header</th><th>Header</th></tr></thead>' +
                        '<tbody><tr><td>Cell</td><td>Cell</td></tr></tbody></table>');
                    break;
                case 'math':
                    document.execCommand('insertHTML', false,
                        '<div class="katex-display">$$<br>$$</div>');
                    break;
                case 'image':
                    document.execCommand('insertHTML', false, '<img src="url" alt="alt text">');
                    break;
            }
            scheduleSyncMarkdown();
        },

        insertText: function(text) {
            document.execCommand('insertText', false, text);
            scheduleSyncMarkdown();
        },

        updateContent: function(markdownText) {
            state.markdown = markdownText || '';
            if (state.mode === 'source') {
                editor.textContent = state.markdown;
            } else {
                renderFullHTML(state.markdown);
            }
            postMessage('contentChanged', { content: state.markdown });
        }
    };

    // ============================================================
    // Event Listeners
    // ============================================================

    editor.addEventListener('input', handleInput);
    editor.addEventListener('keydown', handleKeydown);

    document.addEventListener('selectionchange', function() {
        if (state.focusMode && state.mode === 'preview') updateFocusMode();
    });

    // Ensure editor always has at least a paragraph to type into
    editor.addEventListener('focus', function() {
        if (!editor.innerHTML || editor.innerHTML === '<br>') {
            editor.innerHTML = '<p><br></p>';
            placeCursorInside(editor.querySelector('p'));
        }
    });

    // ============================================================
    // Initialize
    // ============================================================

    function init() {
        if (typeof mermaid !== 'undefined') {
            mermaid.initialize({ startOnLoad: false, theme: 'default', securityLevel: 'loose' });
        }
        postMessage('ready', {});
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();

})();
