import { useRef } from 'react';
import { Paperclip, FileText, X, ExternalLink } from 'lucide-react';

function prettySize(bytes) {
  if (!bytes && bytes !== 0) return '';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

/**
 * Reusable optional document picker.
 * - `files` / `onChange`: pending File objects selected but not yet uploaded.
 * - `existing` / `onRemoveExisting`: already-saved attachments (with file_url).
 */
export default function DocumentUpload({
  files = [],
  onChange,
  existing = [],
  onRemoveExisting,
  label = 'Documents (Optional)',
  multiple = true,
  accept = 'image/*,application/pdf'
}) {
  const inputRef = useRef(null);

  const handleSelect = (e) => {
    const picked = Array.from(e.target.files || []);
    if (picked.length === 0) return;
    onChange(multiple ? [...files, ...picked] : picked.slice(0, 1));
    e.target.value = ''; // allow re-selecting the same file
  };

  const removeFile = (idx) => {
    onChange(files.filter((_, i) => i !== idx));
  };

  return (
    <div>
      <label className="block text-sm text-white/50 mb-1.5">{label}</label>

      {/* Already-saved attachments */}
      {existing.length > 0 && (
        <div className="space-y-2 mb-2">
          {existing.map((att) => (
            <div key={att.id} className="flex items-center gap-2 bg-white/5 border border-white/10 rounded-xl px-3 py-2">
              <FileText className="w-4 h-4 text-cyan-400 shrink-0" />
              <a
                href={att.file_url}
                target="_blank"
                rel="noreferrer"
                className="flex-1 min-w-0 text-sm text-white/80 truncate hover:text-cyan-400 flex items-center gap-1"
              >
                <span className="truncate">{att.file_name}</span>
                <ExternalLink className="w-3 h-3 shrink-0 opacity-60" />
              </a>
              {onRemoveExisting && (
                <button type="button" onClick={() => onRemoveExisting(att)} className="text-white/40 hover:text-red-400 shrink-0">
                  <X className="w-4 h-4" />
                </button>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Pending selections */}
      {files.length > 0 && (
        <div className="space-y-2 mb-2">
          {files.map((file, idx) => (
            <div key={idx} className="flex items-center gap-2 bg-cyan-500/10 border border-cyan-500/20 rounded-xl px-3 py-2">
              <FileText className="w-4 h-4 text-cyan-400 shrink-0" />
              <span className="flex-1 min-w-0 text-sm text-white/80 truncate">{file.name}</span>
              <span className="text-xs text-white/40 shrink-0">{prettySize(file.size)}</span>
              <button type="button" onClick={() => removeFile(idx)} className="text-white/40 hover:text-red-400 shrink-0">
                <X className="w-4 h-4" />
              </button>
            </div>
          ))}
        </div>
      )}

      <button
        type="button"
        onClick={() => inputRef.current?.click()}
        className="w-full flex items-center justify-center gap-2 bg-white/5 border border-dashed border-white/15 rounded-xl px-4 py-2.5 text-white/50 text-sm hover:bg-white/10 hover:text-white/80 transition-all"
      >
        <Paperclip className="w-4 h-4" />
        {files.length > 0 || existing.length > 0 ? 'Add another file' : 'Attach a document'}
      </button>
      <input
        ref={inputRef}
        type="file"
        accept={accept}
        multiple={multiple}
        onChange={handleSelect}
        className="hidden"
      />
    </div>
  );
}
