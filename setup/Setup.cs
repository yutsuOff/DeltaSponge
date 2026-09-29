// DeltaSponge Tool - Setup wizard
// Built with the C# compiler that ships with Windows (.NET Framework 4.x). See build.bat.
//
// What it does:
//   1. Finds DELTARUNE (Steam library folders, or a folder you pick).
//   2. Downloads the official UndertaleModTool CLI (once, cached in %LOCALAPPDATA%\DeltaSponge).
//   3. For each chapter: backs up data.win, patches a clean copy with the mod, puts it back.
//   Uninstall restores the backups.
//
// Silent mode:  DeltaSponge-Setup.exe --install|--uninstall [--path "<DELTARUNE folder>"] [--chapters 1,2,3]

using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("DeltaSponge Tool Setup")]
[assembly: AssemblyProduct("DeltaSponge Tool")]
[assembly: AssemblyDescription("Installer for the DeltaSponge Tool DELTARUNE mod")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

namespace DeltaSponge
{
    static class Program
    {
        [DllImport("kernel32.dll")]
        static extern bool AttachConsole(int pid);

        [STAThread]
        static int Main(string[] args)
        {
            bool install = false, uninstall = false;
            string path = null, chapters = null;
            for (int i = 0; i < args.Length; i++)
            {
                string a = args[i].ToLowerInvariant();
                if (a == "--install") install = true;
                else if (a == "--uninstall") uninstall = true;
                else if (a == "--path" && i + 1 < args.Length) path = args[++i];
                else if (a == "--chapters" && i + 1 < args.Length) chapters = args[++i];
            }

            if (install || uninstall)
                return RunSilent(install, path, chapters);

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new SetupForm());
            return 0;
        }

        static int RunSilent(bool install, string path, string chapterArg)
        {
            AttachConsole(-1);
            Directory.CreateDirectory(Engine.BaseDir);
            string logPath = Path.Combine(Engine.BaseDir, "setup.log");
            using (StreamWriter log = new StreamWriter(logPath, false))
            {
                Engine engine = new Engine();
                engine.Log = delegate (string m) { Console.WriteLine(m); log.WriteLine(m); log.Flush(); };
                try
                {
                    string root = Engine.NormalizeRoot(path ?? Engine.FindGame());
                    List<int> found = Engine.FindChapters(root);
                    if (found.Count == 0)
                        throw new ApplicationException("DELTARUNE not found. Use --path \"<DELTARUNE folder>\".");
                    List<int> selected = found;
                    if (!string.IsNullOrEmpty(chapterArg))
                    {
                        selected = new List<int>();
                        foreach (string s in chapterArg.Split(','))
                        {
                            int n;
                            if (int.TryParse(s.Trim(), out n) && found.Contains(n)) selected.Add(n);
                        }
                    }
                    engine.Log("Game folder: " + root);
                    List<string> failed = engine.Run(root, install, selected, delegate (int p) { });
                    engine.Log(failed.Count == 0 ? "SUCCESS" : "FAILED: " + string.Join(", ", failed.ToArray()));
                    return failed.Count == 0 ? 0 : 1;
                }
                catch (Exception ex)
                {
                    engine.Log("ERROR: " + ex.Message);
                    return 2;
                }
            }
        }
    }

    // =====================================================================
    //  Install / uninstall logic (shared by the wizard and silent mode)
    // =====================================================================
    sealed class Engine
    {
        public const string ModVersion = "1.0";
        public const string UtmtVersion = "0.9.2.0";
        public const string UtmtUrl = "https://github.com/UnderminersTeam/UndertaleModTool/releases/download/" + UtmtVersion + "/UTMT_CLI_v" + UtmtVersion + "-Windows.zip";
        public const string Marker = "obj_deltasponge";

        public Action<string> Log = delegate (string m) { };

        public static string BaseDir
        {
            get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DeltaSponge"); }
        }

        // ---------- Game detection ----------

        public static string FindGame()
        {
            List<string> steams = new List<string>();
            AddPath(steams, Registry.GetValue(@"HKEY_CURRENT_USER\Software\Valve\Steam", "SteamPath", null) as string);
            AddPath(steams, Registry.GetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Valve\Steam", "InstallPath", null) as string);
            AddPath(steams, @"C:\Program Files (x86)\Steam");
            AddPath(steams, @"C:\Program Files\Steam");

            List<string> libs = new List<string>(steams);
            foreach (string steam in steams)
            {
                string vdf = Path.Combine(steam, @"steamapps\libraryfolders.vdf");
                if (!File.Exists(vdf)) continue;
                try
                {
                    foreach (string line in File.ReadAllLines(vdf))
                    {
                        string t = line.Trim();
                        if (!t.StartsWith("\"path\"")) continue;
                        string[] parts = t.Split('"');
                        if (parts.Length >= 4) AddPath(libs, parts[3].Replace(@"\\", @"\"));
                    }
                }
                catch { }
            }

            foreach (string lib in libs)
            {
                string game = Path.Combine(lib, @"steamapps\common\DELTARUNE");
                if (FindChapters(game).Count > 0) return game;
            }
            return null;
        }

        static void AddPath(List<string> list, string p)
        {
            if (string.IsNullOrEmpty(p)) return;
            p = p.Replace('/', '\\').TrimEnd('\\');
            foreach (string e in list)
                if (string.Equals(e, p, StringComparison.OrdinalIgnoreCase)) return;
            list.Add(p);
        }

        public static string NormalizeRoot(string p)
        {
            if (string.IsNullOrEmpty(p)) return "";
            p = p.Trim().Trim('"').TrimEnd('\\');
            // Accept a chapter folder or a data.win path too
            if (p.EndsWith("data.win", StringComparison.OrdinalIgnoreCase)) p = Path.GetDirectoryName(p);
            if (Path.GetFileName(p).StartsWith("chapter", StringComparison.OrdinalIgnoreCase)) p = Path.GetDirectoryName(p);
            return p ?? "";
        }

        public static string ChapterFile(string root, int n)
        {
            return Path.Combine(Path.Combine(root, "chapter" + n + "_windows"), "data.win");
        }

        public static List<int> FindChapters(string root)
        {
            List<int> list = new List<int>();
            if (string.IsNullOrEmpty(root)) return list;
            try
            {
                for (int n = 1; n <= 9; n++)
                    if (File.Exists(ChapterFile(root, n))) list.Add(n);
            }
            catch { }
            return list;
        }

        public static bool IsInstalled(string root, int n)
        {
            try { return FileContains(ChapterFile(root, n), Encoding.ASCII.GetBytes(Marker)); }
            catch { return false; }
        }

        static bool FileContains(string path, byte[] pat)
        {
            using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite, 1 << 20))
            {
                byte[] buf = new byte[4 << 20];
                int keep = 0, read;
                while ((read = fs.Read(buf, keep, buf.Length - keep)) > 0)
                {
                    int len = keep + read;
                    int i = 0;
                    while (i <= len - pat.Length)
                    {
                        i = Array.IndexOf(buf, pat[0], i, len - pat.Length - i + 1);
                        if (i < 0) break;
                        int j = 1;
                        while (j < pat.Length && buf[i + j] == pat[j]) j++;
                        if (j == pat.Length) return true;
                        i++;
                    }
                    keep = Math.Min(pat.Length - 1, len);
                    Buffer.BlockCopy(buf, len - keep, buf, 0, keep);
                }
            }
            return false;
        }

        // ---------- Main entry ----------

        public List<string> Run(string root, bool install, List<int> chapters, Action<int> progress)
        {
            if (IsGameRunning(root))
                throw new ApplicationException("DELTARUNE is running. Close the game and try again.");

            List<string> failed = new List<string>();
            int steps = chapters.Count + (install ? 1 : 0);
            int done = 0;
            string cli = null, csx = null;

            if (install)
            {
                cli = EnsureUtmt();
                csx = ExtractMod();
                done++;
                progress(done * 100 / steps);
            }

            foreach (int n in chapters)
            {
                Log("Chapter " + n + "...");
                try
                {
                    if (install) InstallChapter(root, n, cli, csx);
                    else UninstallChapter(root, n);
                }
                catch (UnauthorizedAccessException)
                {
                    failed.Add("Chapter " + n);
                    Log("  Access denied. Right-click DeltaSponge-Setup.exe > Run as administrator.");
                }
                catch (Exception ex)
                {
                    failed.Add("Chapter " + n);
                    Log("  FAILED: " + ex.Message);
                }
                done++;
                progress(done * 100 / Math.Max(1, steps));
            }
            return failed;
        }

        // Only blocks if the running game is the one in this folder (unknown path = assume it is)
        static bool IsGameRunning(string root)
        {
            foreach (Process p in Process.GetProcessesByName("DELTARUNE"))
            {
                string exe = null;
                try { exe = p.MainModule.FileName; } catch { }
                if (exe == null) return true;
                if (string.Equals(Path.GetDirectoryName(exe).TrimEnd('\\'), root.TrimEnd('\\'), StringComparison.OrdinalIgnoreCase))
                    return true;
            }
            return false;
        }

        void InstallChapter(string root, int n, string cli, string csx)
        {
            string dw = ChapterFile(root, n);
            string bak = dw + ".backup";

            // Always patch a clean copy. If the game was updated, refresh the backup.
            if (!FileContains(dw, Encoding.ASCII.GetBytes(Marker)))
            {
                Log("  Backing up original");
                File.Copy(dw, bak, true);
            }
            else if (!File.Exists(bak))
            {
                throw new ApplicationException("Modded but no backup found. Verify the game files on Steam, then run setup again.");
            }

            string work = Path.Combine(BaseDir, "work");
            Directory.CreateDirectory(work);
            string src = Path.Combine(work, "ch" + n + ".win");
            string dst = Path.Combine(work, "ch" + n + "_mod.win");
            File.Copy(bak, src, true);
            TryDelete(dst);

            Log("  Patching");
            string output = RunCli(cli, "load \"" + src + "\" -s \"" + csx + "\" -o \"" + dst + "\" -f");
            bool ok = File.Exists(dst) && (output.Contains("installed.") || output.Contains("updated."));
            if (!ok)
                throw new ApplicationException("Patch failed:\r\n" + Tail(output, 1500));

            File.Copy(dst, dw, true);
            TryDelete(src);
            TryDelete(dst);
            TryDelete(src + ".backup");
            Log("  OK");
        }

        void UninstallChapter(string root, int n)
        {
            string dw = ChapterFile(root, n);
            string bak = dw + ".backup";
            if (File.Exists(bak))
            {
                File.Copy(bak, dw, true);
                File.Delete(bak);
                Log("  Restored original");
            }
            else if (FileContains(dw, Encoding.ASCII.GetBytes(Marker)))
            {
                throw new ApplicationException("No backup found. Use Steam > Properties > Installed Files > Verify integrity.");
            }
            else
            {
                Log("  Not installed");
            }
        }

        // ---------- UndertaleModTool CLI ----------

        string EnsureUtmt()
        {
            string dir = Path.Combine(BaseDir, "utmt-" + UtmtVersion);
            string exe = FindFile(dir, "UndertaleModCli.exe");
            if (exe != null) return exe;

            // Offline option: a "utmt" folder next to the setup
            exe = FindFile(Path.Combine(Path.GetDirectoryName(Application.ExecutablePath), "utmt"), "UndertaleModCli.exe");
            if (exe != null) return exe;

            Log("Downloading UndertaleModTool " + UtmtVersion + " (60 MB, first time only)...");
            ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072; // TLS 1.2
            Directory.CreateDirectory(BaseDir);
            string zip = Path.Combine(BaseDir, "utmt.zip");
            using (WebClient wc = new WebClient())
            {
                wc.Headers.Add("User-Agent", "DeltaSponge-Setup");
                wc.DownloadFile(UtmtUrl, zip);
            }
            if (Directory.Exists(dir)) Directory.Delete(dir, true);
            ZipFile.ExtractToDirectory(zip, dir);
            TryDelete(zip);

            exe = FindFile(dir, "UndertaleModCli.exe");
            if (exe == null) throw new ApplicationException("UndertaleModCli.exe not found after download.");
            return exe;
        }

        static string FindFile(string dir, string name)
        {
            if (!Directory.Exists(dir)) return null;
            string[] hits = Directory.GetFiles(dir, name, SearchOption.AllDirectories);
            return hits.Length > 0 ? hits[0] : null;
        }

        static string RunCli(string exe, string args)
        {
            ProcessStartInfo psi = new ProcessStartInfo(exe, args);
            psi.UseShellExecute = false;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            psi.CreateNoWindow = true;
            psi.WorkingDirectory = Path.GetDirectoryName(exe);

            StringBuilder sb = new StringBuilder();
            using (Process p = new Process())
            {
                p.StartInfo = psi;
                p.OutputDataReceived += delegate (object s, DataReceivedEventArgs e) { if (e.Data != null) lock (sb) sb.AppendLine(e.Data); };
                p.ErrorDataReceived += delegate (object s, DataReceivedEventArgs e) { if (e.Data != null) lock (sb) sb.AppendLine(e.Data); };
                p.Start();
                p.BeginOutputReadLine();
                p.BeginErrorReadLine();
                p.WaitForExit();
                p.WaitForExit();
            }
            lock (sb) return sb.ToString();
        }

        // ---------- Mod files (embedded in this exe) ----------

        static string ExtractMod()
        {
            string dir = Path.Combine(BaseDir, "mod");
            if (Directory.Exists(dir)) Directory.Delete(dir, true);
            Directory.CreateDirectory(dir);
            Assembly asm = Assembly.GetExecutingAssembly();
            foreach (string name in asm.GetManifestResourceNames())
            {
                if (!name.EndsWith(".csx") && !name.EndsWith(".gml")) continue;
                string target = Path.Combine(dir, name.Replace('/', '\\'));
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                using (Stream s = asm.GetManifestResourceStream(name))
                using (FileStream f = File.Create(target))
                    s.CopyTo(f);
            }
            string csx = Path.Combine(dir, "DeltaSponge_Install.csx");
            if (!File.Exists(csx)) throw new ApplicationException("Mod files missing from the setup.");
            return csx;
        }

        static void TryDelete(string path)
        {
            try { if (File.Exists(path)) File.Delete(path); } catch { }
        }

        static string Tail(string s, int max)
        {
            return s.Length <= max ? s : s.Substring(s.Length - max);
        }
    }

    // =====================================================================
    //  Wizard window
    // =====================================================================
    sealed class SetupForm : Form
    {
        const string SteamRunUrl = "steam://rungameid/1671210";

        static readonly Color Back = Color.Black;
        static readonly Color Fore = Color.White;
        static readonly Color Accent = Color.FromArgb(255, 204, 0);
        static readonly Color Dim = Color.FromArgb(150, 150, 150);
        static readonly Color Box = Color.FromArgb(24, 24, 24);
        static readonly Color Bad = Color.FromArgb(255, 90, 90);

        readonly Panel[] pages = new Panel[5];
        readonly string[] stepNames = { "Welcome", "Step 1 of 3  -  Game folder", "Step 2 of 3  -  Chapters", "Step 3 of 3  -  Working", "Finished" };
        int page;

        Label stepLabel;
        Button backButton, nextButton, cancelButton;
        TextBox pathBox;
        Label pathStatus;
        RadioButton installRadio, uninstallRadio;
        CheckedListBox chapterList;
        readonly List<int> listChapters = new List<int>();
        ProgressBar progressBar;
        Label progressLabel;
        TextBox logBox;
        Label doneTitle, doneText;
        Button launchButton;

        List<int> found = new List<int>();
        string root = "";
        bool busy, lastInstall;
        readonly BackgroundWorker worker = new BackgroundWorker();

        public SetupForm()
        {
            Text = "DeltaSponge Tool Setup";
            ClientSize = new Size(640, 440);
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Back;
            ForeColor = Fore;
            Font = new Font("Segoe UI", 10f);
            try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }

            Label title = MakeLabel("DELTASPONGE TOOL", 24, 16, 420, 40, Accent);
            title.Font = new Font("Segoe UI", 20f, FontStyle.Bold);
            Controls.Add(title);
            Label ver = MakeLabel("v" + Engine.ModVersion, 440, 30, 176, 20, Dim);
            ver.TextAlign = ContentAlignment.MiddleRight;
            Controls.Add(ver);
            stepLabel = MakeLabel("", 26, 58, 580, 22, Dim);
            Controls.Add(stepLabel);
            Panel line = new Panel();
            line.BackColor = Color.FromArgb(70, 70, 70);
            line.SetBounds(24, 86, 592, 1);
            Controls.Add(line);

            for (int i = 0; i < pages.Length; i++)
            {
                pages[i] = new Panel();
                pages[i].SetBounds(24, 100, 592, 276);
                pages[i].Visible = false;
                Controls.Add(pages[i]);
            }
            BuildWelcome(pages[0]);
            BuildLocation(pages[1]);
            BuildChapters(pages[2]);
            BuildProgress(pages[3]);
            BuildDone(pages[4]);

            backButton = MakeButton("< Back", 312, 392, 96, 32);
            nextButton = MakeButton("Next >", 416, 392, 96, 32);
            cancelButton = MakeButton("Cancel", 520, 392, 96, 32);
            backButton.Click += delegate { ShowPage(page - 1); };
            nextButton.Click += delegate { OnNext(); };
            cancelButton.Click += delegate { Close(); };
            Controls.Add(backButton);
            Controls.Add(nextButton);
            Controls.Add(cancelButton);

            worker.WorkerReportsProgress = true;
            worker.DoWork += DoWork;
            worker.ProgressChanged += OnProgress;
            worker.RunWorkerCompleted += OnCompleted;

            FormClosing += delegate (object s, FormClosingEventArgs e)
            {
                if (busy)
                {
                    e.Cancel = true;
                    MessageBox.Show(this, "Please wait until setup is finished.", Text);
                }
            };

            pathBox.Text = Engine.FindGame() ?? "";
            ShowPage(0);
        }

        // ---------- Pages ----------

        void BuildWelcome(Panel p)
        {
            Label h = MakeLabel("Welcome!", 0, 0, 592, 34, Fore);
            h.Font = new Font("Segoe UI", 14f, FontStyle.Bold);
            p.Controls.Add(h);
            p.Controls.Add(MakeLabel(
                "This adds an in-game cheat menu to DELTARUNE.\r\n\r\n" +
                "   \u2022  Fight any boss, anytime\r\n" +
                "   \u2022  Change your party, stats and items\r\n" +
                "   \u2022  God mode, one-hit kill, 1 HP mode, auto spare, infinite TP\r\n\r\n" +
                "In game, press  `  or  F9  to open the menu.",
                0, 44, 592, 170, Fore));
            p.Controls.Add(MakeLabel("Close DELTARUNE before continuing.", 0, 244, 592, 24, Dim));
        }

        void BuildLocation(Panel p)
        {
            Label h = MakeLabel("Where is DELTARUNE installed?", 0, 0, 592, 30, Fore);
            h.Font = new Font("Segoe UI", 12f, FontStyle.Bold);
            p.Controls.Add(h);

            pathBox = new TextBox();
            pathBox.SetBounds(0, 50, 480, 28);
            pathBox.BackColor = Box;
            pathBox.ForeColor = Fore;
            pathBox.BorderStyle = BorderStyle.FixedSingle;
            pathBox.TextChanged += delegate { RefreshPath(); };
            p.Controls.Add(pathBox);

            Button browse = MakeButton("Browse...", 490, 47, 102, 32);
            browse.Click += delegate
            {
                using (FolderBrowserDialog d = new FolderBrowserDialog())
                {
                    d.Description = "Select the DELTARUNE folder";
                    if (Directory.Exists(pathBox.Text)) d.SelectedPath = pathBox.Text;
                    if (d.ShowDialog(this) == DialogResult.OK) pathBox.Text = d.SelectedPath;
                }
            };
            p.Controls.Add(browse);

            pathStatus = MakeLabel("", 0, 96, 592, 50, Dim);
            p.Controls.Add(pathStatus);
        }

        void BuildChapters(Panel p)
        {
            installRadio = MakeRadio("Install / update", 0, 0, 190);
            uninstallRadio = MakeRadio("Uninstall", 200, 0, 150);
            installRadio.Checked = true;
            installRadio.CheckedChanged += delegate { FillChapters(); };
            p.Controls.Add(installRadio);
            p.Controls.Add(uninstallRadio);

            chapterList = new CheckedListBox();
            chapterList.SetBounds(0, 40, 592, 196);
            chapterList.BackColor = Box;
            chapterList.ForeColor = Fore;
            chapterList.BorderStyle = BorderStyle.None;
            chapterList.CheckOnClick = true;
            chapterList.Font = new Font("Segoe UI", 12f);
            p.Controls.Add(chapterList);

            p.Controls.Add(MakeLabel("Originals are backed up automatically.", 0, 248, 592, 24, Dim));
        }

        void BuildProgress(Panel p)
        {
            progressLabel = MakeLabel("Working...", 0, 0, 592, 26, Fore);
            p.Controls.Add(progressLabel);

            progressBar = new ProgressBar();
            progressBar.SetBounds(0, 32, 592, 20);
            progressBar.Style = ProgressBarStyle.Continuous;
            p.Controls.Add(progressBar);

            logBox = new TextBox();
            logBox.SetBounds(0, 64, 592, 208);
            logBox.Multiline = true;
            logBox.ReadOnly = true;
            logBox.ScrollBars = ScrollBars.Vertical;
            logBox.BackColor = Box;
            logBox.ForeColor = Dim;
            logBox.BorderStyle = BorderStyle.None;
            logBox.Font = new Font("Consolas", 9.5f);
            p.Controls.Add(logBox);
        }

        void BuildDone(Panel p)
        {
            doneTitle = MakeLabel("", 0, 0, 592, 36, Accent);
            doneTitle.Font = new Font("Segoe UI", 16f, FontStyle.Bold);
            p.Controls.Add(doneTitle);
            doneText = MakeLabel("", 0, 48, 592, 150, Fore);
            p.Controls.Add(doneText);
            launchButton = MakeButton("Launch DELTARUNE", 0, 214, 200, 36);
            launchButton.Click += delegate
            {
                try { Process.Start(SteamRunUrl); } catch { }
                Close();
            };
            p.Controls.Add(launchButton);
        }

        // ---------- Navigation ----------

        void ShowPage(int i)
        {
            if (i < 0 || i >= pages.Length) return;
            page = i;
            for (int k = 0; k < pages.Length; k++) pages[k].Visible = (k == i);
            stepLabel.Text = stepNames[i];

            backButton.Visible = (i == 1 || i == 2);
            cancelButton.Visible = (i < 3);
            nextButton.Visible = (i != 3);
            nextButton.Enabled = true;
            nextButton.Text = (i == 4) ? "Close" : "Next >";
            nextButton.Left = (i == 4) ? 520 : 416;

            if (i == 1) RefreshPath();
            if (i == 2) FillChapters();
            nextButton.Focus();
        }

        void OnNext()
        {
            switch (page)
            {
                case 0: ShowPage(1); break;
                case 1: ShowPage(2); break;
                case 2: StartWork(); break;
                case 4: Close(); break;
            }
        }

        void RefreshPath()
        {
            root = Engine.NormalizeRoot(pathBox.Text);
            found = Engine.FindChapters(root);
            if (found.Count > 0)
            {
                List<string> names = new List<string>();
                foreach (int n in found) names.Add(n.ToString());
                pathStatus.Text = "Found chapters: " + string.Join(", ", names.ToArray());
                pathStatus.ForeColor = Accent;
            }
            else
            {
                pathStatus.Text = string.IsNullOrEmpty(root) ? "Pick your DELTARUNE folder." : "DELTARUNE not found in this folder.";
                pathStatus.ForeColor = string.IsNullOrEmpty(root) ? Dim : Bad;
            }
            if (page == 1) nextButton.Enabled = found.Count > 0;
        }

        void FillChapters()
        {
            bool install = installRadio.Checked;
            Cursor = Cursors.WaitCursor;
            chapterList.Items.Clear();
            listChapters.Clear();
            foreach (int n in found)
            {
                bool inst = Engine.IsInstalled(root, n);
                chapterList.Items.Add("Chapter " + n + (inst ? "      installed" : ""), install || inst);
                listChapters.Add(n);
            }
            Cursor = Cursors.Default;
            nextButton.Text = install ? "Install" : "Uninstall";
        }

        void StartWork()
        {
            List<int> selected = new List<int>();
            for (int i = 0; i < chapterList.Items.Count; i++)
                if (chapterList.GetItemChecked(i)) selected.Add(listChapters[i]);
            if (selected.Count == 0)
            {
                MessageBox.Show(this, "Check at least one chapter.", Text);
                return;
            }

            lastInstall = installRadio.Checked;
            logBox.Clear();
            progressBar.Value = 0;
            progressLabel.Text = lastInstall ? "Installing..." : "Uninstalling...";
            busy = true;
            ShowPage(3);
            worker.RunWorkerAsync(new object[] { lastInstall, selected, root });
        }

        // ---------- Background work ----------

        void DoWork(object sender, DoWorkEventArgs e)
        {
            object[] a = (object[])e.Argument;
            Engine engine = new Engine();
            engine.Log = delegate (string m) { worker.ReportProgress(-1, m); };
            e.Result = engine.Run((string)a[2], (bool)a[0], (List<int>)a[1], delegate (int p) { worker.ReportProgress(p, null); });
        }

        void OnProgress(object sender, ProgressChangedEventArgs e)
        {
            if (e.ProgressPercentage >= 0) progressBar.Value = Math.Max(0, Math.Min(100, e.ProgressPercentage));
            string m = e.UserState as string;
            if (m != null)
            {
                logBox.AppendText(m + "\r\n");
                if (!m.StartsWith("  ")) progressLabel.Text = m;
            }
        }

        void OnCompleted(object sender, RunWorkerCompletedEventArgs e)
        {
            busy = false;
            List<string> failed = (e.Error == null) ? (List<string>)e.Result : null;
            bool ok = failed != null && failed.Count == 0;

            if (ok)
            {
                doneTitle.Text = lastInstall ? "Done!" : "Uninstalled";
                doneTitle.ForeColor = Accent;
                doneText.Text = lastInstall
                    ? "Start DELTARUNE, load a save and press  `  or  F9.\r\n\r\nIf Steam updates the game, run this setup again."
                    : "DELTARUNE is back to normal.";
                launchButton.Visible = lastInstall;
                ShowPage(4);
            }
            else
            {
                string why = (e.Error != null) ? e.Error.Message : "Failed: " + string.Join(", ", failed.ToArray()) + ". See the log above.";
                logBox.AppendText("\r\n" + why + "\r\n");
                progressLabel.Text = "Something went wrong";
                progressLabel.ForeColor = Bad;
                nextButton.Visible = true;
                nextButton.Text = "Close";
                nextButton.Left = 520;
                page = 4; // "Close" button now closes the window
                if (e.Error != null) MessageBox.Show(this, e.Error.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        // ---------- Styled controls ----------

        static Label MakeLabel(string text, int x, int y, int w, int h, Color c)
        {
            Label l = new Label();
            l.Text = text;
            l.SetBounds(x, y, w, h);
            l.ForeColor = c;
            l.BackColor = Color.Transparent;
            return l;
        }

        static Button MakeButton(string text, int x, int y, int w, int h)
        {
            Button b = new Button();
            b.Text = text;
            b.SetBounds(x, y, w, h);
            b.FlatStyle = FlatStyle.Flat;
            b.BackColor = Back;
            b.ForeColor = Fore;
            b.FlatAppearance.BorderColor = Fore;
            b.FlatAppearance.BorderSize = 2;
            b.FlatAppearance.MouseOverBackColor = Color.FromArgb(50, 42, 0);
            b.FlatAppearance.MouseDownBackColor = Color.FromArgb(90, 75, 0);
            b.Cursor = Cursors.Hand;
            b.MouseEnter += delegate { b.ForeColor = Accent; b.FlatAppearance.BorderColor = Accent; };
            b.MouseLeave += delegate { b.ForeColor = Fore; b.FlatAppearance.BorderColor = Fore; };
            return b;
        }

        static RadioButton MakeRadio(string text, int x, int y, int w)
        {
            RadioButton r = new RadioButton();
            r.Text = text;
            r.SetBounds(x, y, w, 28);
            r.ForeColor = Fore;
            r.BackColor = Color.Transparent;
            r.FlatStyle = FlatStyle.Standard;
            r.Cursor = Cursors.Hand;
            return r;
        }
    }
}
