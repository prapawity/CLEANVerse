from __future__ import annotations
import json
import os
import queue
import threading
import tkinter as tk
from datetime import datetime
from pathlib import Path
from tkinter import filedialog, messagebox, ttk
from scanner import scan, unchanged

APP = 'Device Care'
def readable(size):
    value = float(size)
    for unit in ('B','KB','MB','GB','TB'):
        if value < 1024 or unit == 'TB': return f'{value:.1f} {unit}'
        value /= 1024

class App(tk.Tk):
    def __init__(self):
        super().__init__(); self.title(APP); self.geometry('1060x700'); self.minsize(760, 500)
        self.queue = queue.Queue(); self.cancel_event = threading.Event(); self.records = {}; self.exclusions = []; self.result = None
        self.protocol('WM_DELETE_WINDOW', self.close)
        style = ttk.Style(self); style.theme_use('clam'); style.configure('Title.TLabel', font=('Segoe UI', 22, 'bold')); style.configure('Sub.TLabel', font=('Segoe UI', 10)); style.configure('Treeview', rowheight=27)
        top = ttk.Frame(self, padding=(22,18)); top.pack(fill='x')
        ttk.Label(top, text='A clearer view of your space', style='Title.TLabel').pack(anchor='w')
        ttk.Label(top, text='Scan a folder locally. Nothing is selected or removed automatically.', style='Sub.TLabel').pack(anchor='w', pady=(4,12))
        actions = ttk.Frame(top); actions.pack(fill='x')
        self.root_var = tk.StringVar(); ttk.Entry(actions, textvariable=self.root_var).pack(side='left', fill='x', expand=True)
        ttk.Button(actions, text='Choose folder', command=self.choose).pack(side='left', padx=5)
        self.scan_button = ttk.Button(actions, text='Scan', command=self.start); self.scan_button.pack(side='left')
        ttk.Button(actions, text='Cancel', command=self.cancel_event.set).pack(side='left', padx=5)
        ttk.Button(actions, text='Exclude folder', command=self.exclude).pack(side='left')
        self.exclusion_label = ttk.Label(top, text='Excluded folders: 0'); self.exclusion_label.pack(anchor='w', pady=(8,0))
        self.status = tk.StringVar(value='Choose a folder to get started.'); ttk.Label(top, textvariable=self.status).pack(anchor='w', pady=(7,0))
        body = ttk.Frame(self, padding=(22,0,22,12)); body.pack(fill='both', expand=True)
        controls = ttk.Frame(body); controls.pack(fill='x', pady=(0,8))
        ttk.Label(controls, text='View:').pack(side='left'); self.mode = tk.StringVar(value='Largest files')
        view = ttk.Combobox(controls, textvariable=self.mode, state='readonly', values=['Largest files','Exact duplicates'], width=20); view.pack(side='left', padx=6); view.bind('<<ComboboxSelected>>', lambda _: self.render())
        ttk.Button(controls, text='Show scan issues', command=self.show_issues).pack(side='right')
        self.tree = ttk.Treeview(body, columns=('size','group','path'), show='headings', selectmode='extended'); self.tree.heading('size',text='Size'); self.tree.heading('group',text='Duplicate group'); self.tree.heading('path',text='File'); self.tree.column('size',width=105,stretch=False); self.tree.column('group',width=135,stretch=False); self.tree.column('path',width=650)
        scroll = ttk.Scrollbar(body, orient='vertical', command=self.tree.yview); self.tree.configure(yscrollcommand=scroll.set); scroll.pack(side='right',fill='y'); self.tree.pack(fill='both',expand=True)
        bottom=ttk.Frame(self,padding=(22,0,22,20)); bottom.pack(fill='x'); ttk.Label(bottom,text='Select files deliberately. Cloud-synced items may also be removed from the cloud.').pack(side='left'); ttk.Button(bottom,text='Move selected to Trash…',command=self.remove).pack(side='right')
        self.after(100,self.poll)
    def choose(self):
        p=filedialog.askdirectory(title='Choose a folder to scan');
        if p: self.root_var.set(p)
    def exclude(self):
        p=filedialog.askdirectory(title='Exclude a folder from scanning')
        if p:
            self.exclusions.append(Path(p)); self.exclusion_label.config(text='Excluded folders: '+', '.join(str(x) for x in self.exclusions))
    def start(self):
        if not self.root_var.get().strip(): messagebox.showinfo(APP,'Choose a folder first.'); return
        self.cancel_event.clear(); self.scan_button.config(state='disabled'); self.status.set('Scanning locally…'); self.records={}; self.tree.delete(*self.tree.get_children()); self.result=None
        root=Path(self.root_var.get()); exclusions=list(self.exclusions)
        def run():
            try: self.queue.put(('done',scan(root,exclusions,self.cancel_event,lambda n:self.queue.put(('progress',n)))))
            except Exception as exc: self.queue.put(('error',str(exc)))
        threading.Thread(target=run,daemon=True).start()
    def poll(self):
        try:
            while True:
                kind,value=self.queue.get_nowait()
                if kind=='progress': self.status.set(f'Scanning locally… {value:,} files found')
                elif kind=='error': self.scan_button.config(state='normal'); self.status.set('Scan failed.'); messagebox.showerror(APP,value)
                else:
                    self.scan_button.config(state='normal'); self.result=value
                    self.status.set(f'{"Cancelled. Partial results" if value.cancelled else "Scan complete"}: {len(value.files):,} files, {len(value.duplicates):,} duplicate groups, {len(value.errors):,} issues.'); self.render()
        except queue.Empty: pass
        self.after(100,self.poll)
    def render(self):
        self.tree.delete(*self.tree.get_children()); self.records={}
        if not self.result:return
        if self.mode.get()=='Exact duplicates': rows=[(r,i) for i,g in enumerate(self.result.duplicates,1) for r in g]
        else: rows=[(r,'') for r in sorted(self.result.files,key=lambda x:x.size,reverse=True)[:5000]]
        for index,(r,group) in enumerate(rows):
            key=str(index); self.records[key]=r; self.tree.insert('', 'end', iid=key, values=(readable(r.size),group,str(r.path)))
    def show_issues(self):
        if not self.result: return
        text='\n'.join(self.result.errors[:30]) or 'No scan issues.'
        if len(self.result.errors)>30:text+=f'\n… and {len(self.result.errors)-30} more.'
        messagebox.showinfo('Scan issues',text)
    def remove(self):
        chosen=[self.records[x] for x in self.tree.selection() if x in self.records]
        if not chosen: messagebox.showinfo(APP,'Select one or more files first.'); return
        try: from send2trash import send2trash
        except ImportError: messagebox.showerror(APP,'Trash support is missing. Install dependencies using the instructions in README.'); return
        total=sum(x.size for x in chosen)
        if not messagebox.askyesno('Review removal',f'Move {len(chosen)} selected file(s), totaling {readable(total)}, to your system Trash?\n\nReview paths in the list first. Synced files may be removed on other devices. Trash recovery depends on the system and volume.') :return
        done=[]; failures=[]
        for rec in chosen:
            if not unchanged(rec): failures.append(f'{rec.path}: changed or unavailable; skipped'); continue
            try: send2trash(str(rec.path)); done.append(rec)
            except Exception as exc: failures.append(f'{rec.path}: {exc}')
        # Log only paths explicitly removed, locally, in the user's application data.
        try:
            folder=Path(os.environ.get('APPDATA',Path.home()/'.local'/'share'))/'DeviceCare'; folder.mkdir(parents=True,exist_ok=True)
            with (folder/'history.jsonl').open('a',encoding='utf-8') as f:
                for rec in done: f.write(json.dumps({'time':datetime.now().astimezone().isoformat(),'action':'moved_to_trash','path':str(rec.path),'size':rec.size})+'\n')
        except OSError as exc: failures.append(f'History could not be saved: {exc}')
        if self.result:
            removed={r.path for r in done}; self.result.files=[r for r in self.result.files if r.path not in removed]; self.result.duplicates=[[r for r in g if r.path not in removed] for g in self.result.duplicates]; self.result.duplicates=[g for g in self.result.duplicates if len(g)>1]; self.render()
        self.status.set(f'Moved {len(done)} file(s) to Trash. Space may not be freed until Trash is emptied.')
        messagebox.showinfo('Removal results',f'Moved to Trash: {len(done)}\nSkipped or failed: {len(failures)}'+ ('\n\n'+'\n'.join(failures[:10]) if failures else ''))
    def close(self):
        self.cancel_event.set(); self.destroy()
if __name__=='__main__': App().mainloop()

