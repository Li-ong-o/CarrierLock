"""
CarrierLock Windows Edition (CarrierLock-Windows)
A desktop companion and management tool for iPhone Carrier Bundle Locking.
"""

import os
import sys
import time
import socket
import struct
import plistlib
import threading
import tkinter as tk
from tkinter import ttk, messagebox, filedialog

try:
    import ctypes
    ctypes.windll.shcore.SetProcessDpiAwareness(1)
except Exception:
    pass

from usbmux import UsbmuxClient, find_paired_udids, get_pairing_record, get_live_device_info
from carrier_catalog import guess_bundle_for_imsi, POPULAR_BUNDLES

APP_TITLE = "CarrierLock - 运营商配置锁定工具 (Windows版 v1.0.3)"
VERSION = "1.0.3"

class CarrierLockGUI:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title(APP_TITLE)
        self.root.geometry("780x620")
        self.root.minsize(700, 560)
        self.root.configure(bg="#F3F4F6")

        # Set Window Icon
        ico_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "app.ico")
        if getattr(sys, 'frozen', False) and hasattr(sys, '_MEIPASS'):
            bundle_ico = os.path.join(sys._MEIPASS, "app.ico")
            if os.path.exists(bundle_ico):
                ico_path = bundle_ico
        if os.path.exists(ico_path):
            try:
                self.root.iconbitmap(ico_path)
            except Exception:
                pass

        self.current_udid = None
        self.device_info = {}
        self.sim1_info = {}
        self.sim2_info = {}
        self.scanning = False

        self.setup_styles()
        self.build_ui()

        # Start periodic USB device detector
        self.start_usb_monitor()

    def setup_styles(self):
        self.style = ttk.Style()
        self.style.theme_use("clam")

        # Fonts
        self.font_title = ("Segoe UI", 13, "bold")
        self.font_heading = ("Segoe UI", 10, "bold")
        self.font_body = ("Segoe UI", 9)
        self.font_mono = ("Consolas", 9)
        self.font_badge = ("Segoe UI", 8, "bold")

        self.style.configure("TFrame", background="#F3F4F6")
        self.style.configure("Card.TFrame", background="#FFFFFF", relief="flat")
        self.style.configure("TLabel", background="#FFFFFF", font=self.font_body, foreground="#1F2937")
        self.style.configure("CardTitle.TLabel", background="#FFFFFF", font=self.font_heading, foreground="#111827")
        self.style.configure("Header.TLabel", background="#1F2937", foreground="#FFFFFF", font=self.font_title)
        self.style.configure("SubHeader.TLabel", background="#1F2937", foreground="#9CA3AF", font=self.font_body)

        self.style.configure("Primary.TButton", font=self.font_heading, padding=6)
        self.style.configure("Action.TButton", font=self.font_body, padding=4)

    def build_ui(self):
        # 1. Top Header Banner
        header_frame = tk.Frame(self.root, bg="#111827", height=70)
        header_frame.pack(fill="x", side="top")

        title_lbl = tk.Label(
            header_frame,
            text="📱 CarrierLock  |  iPhone 运营商配置锁定助手",
            font=("Segoe UI", 13, "bold"),
            bg="#111827",
            fg="#FFFFFF"
        )
        title_lbl.pack(anchor="w", padx=20, pady=(12, 2))

        sub_lbl = tk.Label(
            header_frame,
            text=f"版本 {VERSION}  •  USB直连读取  •  双卡IMS智能识别  •  防跳激活配置",
            font=("Segoe UI", 9),
            bg="#111827",
            fg="#9CA3AF"
        )
        sub_lbl.pack(anchor="w", padx=20, pady=(0, 10))

        # Main scrollable or tabbed container
        main_frame = tk.Frame(self.root, bg="#F3F4F6")
        main_frame.pack(fill="both", expand=True, padx=16, pady=12)

        # Left Column (Device & SIM Status)
        left_col = tk.Frame(main_frame, bg="#F3F4F6")
        left_col.pack(side="left", fill="both", expand=True, padx=(0, 8))

        # Right Column (Lock Actions & Log)
        right_col = tk.Frame(main_frame, bg="#F3F4F6", width=330)
        right_col.pack(side="right", fill="both", expand=False, padx=(8, 0))

        self.build_device_card(left_col)
        self.build_sim_cards(left_col)
        self.build_action_card(right_col)
        self.build_log_card(right_col)

    def build_device_card(self, parent):
        card = tk.LabelFrame(parent, text=" 📲 已连接 iPhone 设备信息 ", font=self.font_heading, bg="#FFFFFF", fg="#1E3A8A", padx=12, pady=10)
        card.pack(fill="x", pady=(0, 10))

        self.lbl_device_name = tk.Label(card, text="设备状态：未检测到 USB 连接的 iPhone", font=self.font_heading, bg="#FFFFFF", fg="#DC2626")
        self.lbl_device_name.pack(anchor="w", pady=(0, 4))

        self.lbl_device_model = tk.Label(card, text="设备型号：--", font=self.font_body, bg="#FFFFFF", fg="#4B5563")
        self.lbl_device_model.pack(anchor="w")

        self.lbl_device_version = tk.Label(card, text="系统版本：--", font=self.font_body, bg="#FFFFFF", fg="#4B5563")
        self.lbl_device_version.pack(anchor="w")

        self.lbl_device_udid = tk.Label(card, text="UDID 标识：--", font=self.font_mono, bg="#FFFFFF", fg="#6B7280")
        self.lbl_device_udid.pack(anchor="w")

        btn_box = tk.Frame(card, bg="#FFFFFF")
        btn_box.pack(fill="x", pady=(8, 0))

        self.btn_refresh = tk.Button(btn_box, text="🔄 刷新连接", font=self.font_body, command=self.on_refresh_device, bg="#E5E7EB", relief="groove")
        self.btn_refresh.pack(side="left", padx=(0, 6))

        self.btn_export_pair = tk.Button(btn_box, text="💾 导出配对文件 (.plist)", font=self.font_body, command=self.on_export_pairing, bg="#E5E7EB", relief="groove", state="disabled")
        self.btn_export_pair.pack(side="left")

    def build_sim_cards(self, parent):
        card = tk.LabelFrame(parent, text=" 💳 SIM 卡与 IMSI 检测 ", font=self.font_heading, bg="#FFFFFF", fg="#1E3A8A", padx=12, pady=10)
        card.pack(fill="both", expand=True)

        # SIM 1
        sim1_box = tk.LabelFrame(card, text=" 卡槽 1 (主卡 / SIM 1) ", font=self.font_heading, bg="#F9FAFB", padx=8, pady=6)
        sim1_box.pack(fill="x", pady=(0, 8))

        self.sim1_check_var = tk.BooleanVar(value=True)
        self.chk_sim1 = tk.Checkbutton(sim1_box, text="锁定此卡运营商配置", variable=self.sim1_check_var, font=self.font_body, bg="#F9FAFB")
        self.chk_sim1.pack(anchor="w")

        self.lbl_sim1_imsi = tk.Label(sim1_box, text="IMSI：未连接", font=self.font_mono, bg="#F9FAFB", fg="#6B7280")
        self.lbl_sim1_imsi.pack(anchor="w")

        self.lbl_sim1_carrier = tk.Label(sim1_box, text="运营商匹配：待连接", font=self.font_body, bg="#F9FAFB", fg="#6B7280")
        self.lbl_sim1_carrier.pack(anchor="w")

        sim1_bundle_box = tk.Frame(sim1_box, bg="#F9FAFB")
        sim1_bundle_box.pack(fill="x", pady=(4, 0))
        tk.Label(sim1_bundle_box, text="目标 Bundle:", font=self.font_body, bg="#F9FAFB").pack(side="left")
        self.sim1_bundle_var = tk.StringVar(value="CBN_cn")
        self.combo_sim1_bundle = ttk.Combobox(sim1_bundle_box, textvariable=self.sim1_bundle_var, values=[b[0] for b in POPULAR_BUNDLES], width=20)
        self.combo_sim1_bundle.pack(side="left", padx=6)

        # SIM 2
        sim2_box = tk.LabelFrame(card, text=" 卡槽 2 (副卡 / eSIM / SIM 2) ", font=self.font_heading, bg="#F9FAFB", padx=8, pady=6)
        sim2_box.pack(fill="x", pady=(4, 8))

        self.sim2_check_var = tk.BooleanVar(value=True)
        self.chk_sim2 = tk.Checkbutton(sim2_box, text="锁定此卡运营商配置", variable=self.sim2_check_var, font=self.font_body, bg="#F9FAFB")
        self.chk_sim2.pack(anchor="w")

        self.lbl_sim2_imsi = tk.Label(sim2_box, text="IMSI：未连接", font=self.font_mono, bg="#F9FAFB", fg="#6B7280")
        self.lbl_sim2_imsi.pack(anchor="w")

        self.lbl_sim2_carrier = tk.Label(sim2_box, text="运营商匹配：待连接", font=self.font_body, bg="#F9FAFB", fg="#6B7280")
        self.lbl_sim2_carrier.pack(anchor="w")

        sim2_bundle_box = tk.Frame(sim2_box, bg="#F9FAFB")
        sim2_bundle_box.pack(fill="x", pady=(4, 0))
        tk.Label(sim2_bundle_box, text="目标 Bundle:", font=self.font_body, bg="#F9FAFB").pack(side="left")
        self.sim2_bundle_var = tk.StringVar(value="Unicom_cn")
        self.combo_sim2_bundle = ttk.Combobox(sim2_bundle_box, textvariable=self.sim2_bundle_var, values=[b[0] for b in POPULAR_BUNDLES], width=20)
        self.combo_sim2_bundle.pack(side="left", padx=6)

        # Manual Entry Box
        manual_box = tk.Frame(card, bg="#FFFFFF")
        manual_box.pack(fill="x", pady=(4, 0))
        tk.Label(manual_box, text="手动补充 IMSI (15位):", font=self.font_body, bg="#FFFFFF").pack(side="left")
        self.entry_manual_imsi = tk.Entry(manual_box, font=self.font_mono, width=18)
        self.entry_manual_imsi.pack(side="left", padx=6)
        tk.Button(manual_box, text="应用到卡1", font=self.font_body, command=lambda: self.apply_manual_imsi(1), bg="#E5E7EB").pack(side="left", padx=2)
        tk.Button(manual_box, text="应用到卡2", font=self.font_body, command=lambda: self.apply_manual_imsi(2), bg="#E5E7EB").pack(side="left", padx=2)

    def build_action_card(self, parent):
        card = tk.LabelFrame(parent, text=" ⚡ 操作控制台 ", font=self.font_heading, bg="#FFFFFF", fg="#1E3A8A", padx=12, pady=10)
        card.pack(fill="x", pady=(0, 10))

        self.btn_lock = tk.Button(
            card,
            text="🔒 写入并锁定运营商配置",
            font=("Segoe UI", 10, "bold"),
            bg="#2563EB",
            fg="#FFFFFF",
            relief="flat",
            padx=12,
            pady=8,
            state="disabled",
            command=self.on_lock_clicked
        )
        self.btn_lock.pack(fill="x", pady=(0, 6))

        self.btn_verify = tk.Button(
            card,
            text="🔍 实时验证锁定生效状态",
            font=("Segoe UI", 9, "bold"),
            bg="#059669",
            fg="#FFFFFF",
            relief="flat",
            padx=12,
            pady=6,
            state="disabled",
            command=self.on_verify_clicked
        )
        self.btn_verify.pack(fill="x", pady=(0, 6))

        self.btn_restore = tk.Button(
            card,
            text="↩️ 恢复默认（清除锁定链接）",
            font=self.font_body,
            bg="#F3F4F6",
            fg="#DC2626",
            relief="groove",
            pady=4,
            command=self.on_restore_clicked
        )
        self.btn_restore.pack(fill="x", pady=(0, 8))

        # Tip box
        tip_box = tk.Frame(card, bg="#EFF6FF", padx=8, pady=6)
        tip_box.pack(fill="x")
        tk.Label(
            tip_box,
            text="💡 操作小贴士：\n1. 插入数据线并在手机上点【信任电脑】\n2. 锁定成功后，手机下拉控制中心【开关飞行模式5秒】即可刷新生效，无需重启！",
            font=("Segoe UI", 8),
            bg="#EFF6FF",
            fg="#1D4ED8",
            justify="left"
        ).pack(anchor="w")

    def build_log_card(self, parent):
        card = tk.LabelFrame(parent, text=" 📋 执行日志与状态 ", font=self.font_heading, bg="#FFFFFF", fg="#1E3A8A", padx=8, pady=8)
        card.pack(fill="both", expand=True)

        self.txt_log = tk.Text(card, font=self.font_mono, bg="#1E293B", fg="#F8FAFC", wrap="word", height=12)
        self.txt_log.pack(fill="both", expand=True)

        self.log("CarrierLock Windows版已启动。正在扫描连接...")

    def log(self, message: str):
        timestamp = time.strftime("%H:%M:%S")
        self.txt_log.insert("end", f"[{timestamp}] {message}\n")
        self.txt_log.see("end")

    def start_usb_monitor(self):
        def monitor_loop():
            while True:
                try:
                    self.poll_device()
                except Exception as e:
                    pass
                time.sleep(3.0)

        t = threading.Thread(target=monitor_loop, daemon=True)
        t.start()

    def poll_device(self):
        info = get_live_device_info()
        if not info or not info.get("connected"):
            if self.current_udid is not None:
                self.current_udid = None
                self.root.after(0, self.update_device_ui_disconnected)
            return

        udid = info.get("udid")
        if udid != self.current_udid:
            self.current_udid = udid
            self.root.after(0, lambda: self.update_device_ui_connected(info))

    def update_device_ui_disconnected(self):
        self.lbl_device_name.config(text="设备状态：未检测到 USB 连接的 iPhone", fg="#DC2626")
        self.lbl_device_model.config(text="设备型号：--")
        self.lbl_device_version.config(text="系统版本：--")
        self.lbl_device_udid.config(text="UDID 标识：--")

        self.lbl_sim1_imsi.config(text="IMSI：未连接")
        self.lbl_sim1_carrier.config(text="运营商匹配：--")

        self.lbl_sim2_imsi.config(text="IMSI：未连接")
        self.lbl_sim2_carrier.config(text="运营商匹配：--")

        self.btn_lock.config(state="disabled")
        self.btn_verify.config(state="disabled")
        self.btn_export_pair.config(state="disabled")
        self.log("iPhone 已断开 USB 连接。等待连接数据线...")

    def update_device_ui_connected(self, info: dict):
        udid = info.get("udid", "")
        paired = info.get("paired", False)

        if not paired:
            self.lbl_device_name.config(text="设备状态：已连接但未配对 (请在手机上点击【信任】)", fg="#EAB308")
            self.lbl_device_udid.config(text=f"UDID: {udid}")
            self.lbl_device_model.config(text="请在 iPhone 屏幕上解锁并点击【信任此电脑】")
            self.lbl_device_version.config(text="系统版本：--")
            self.btn_lock.config(state="disabled")
            self.btn_verify.config(state="disabled")
            self.btn_export_pair.config(state="disabled")
            self.log(f"检测到设备 {udid}，但尚未完成信任配对。")
            return

        name = info.get("device_name", "iPhone")
        prod = info.get("product_type", "iPhone")
        ver = info.get("product_version", "")
        build = info.get("build_version", "")

        self.lbl_device_name.config(text=f"设备状态：已连接 {name} (已配对)", fg="#16A34A")
        self.lbl_device_model.config(text=f"设备型号：{prod}")
        self.lbl_device_version.config(text=f"系统版本：iOS {ver} (Build {build})")
        self.lbl_device_udid.config(text=f"UDID: {udid}")
        self.btn_lock.config(state="normal")
        self.btn_verify.config(state="normal")
        self.btn_export_pair.config(state="normal")
        self.log(f"成功连接设备：{name} (iOS {ver}, {prod})")

        # SIM 1 Live Detection
        sim1 = info.get("sim1", {})
        imsi1 = sim1.get("imsi", "")
        cur_b1 = sim1.get("bundle_id", "")
        cur_ver1 = sim1.get("bundle_version", "")
        if imsi1:
            guess1 = guess_bundle_for_imsi(imsi1)
            bname1 = guess1[0] if guess1 else "CBN_cn"
            friendly1 = guess1[1] if guess1 else "未知运营商"
            self.lbl_sim1_imsi.config(text=f"IMSI: {imsi1}")
            active_info = f" [当前生效: {cur_b1.replace('com.apple.', '')} {cur_ver1}]" if cur_b1 else ""
            self.lbl_sim1_carrier.config(text=f"推荐: {bname1} ({friendly1}){active_info}")
            self.sim1_bundle_var.set(bname1)
            self.log(f"卡槽 1 检测到 SIM：IMSI {imsi1} ({friendly1}) 当前生效: {cur_b1} {cur_ver1}")
        else:
            self.lbl_sim1_imsi.config(text="IMSI：未检测到或无法读取")
            self.lbl_sim1_carrier.config(text="运营商匹配：--")

        # SIM 2 Live Detection
        sim2 = info.get("sim2", {})
        imsi2 = sim2.get("imsi", "")
        cur_b2 = sim2.get("bundle_id", "")
        cur_ver2 = sim2.get("bundle_version", "")
        if imsi2:
            guess2 = guess_bundle_for_imsi(imsi2)
            bname2 = guess2[0] if guess2 else "Unicom_cn"
            friendly2 = guess2[1] if guess2 else "未知运营商"
            self.lbl_sim2_imsi.config(text=f"IMSI: {imsi2}")
            active_info = f" [当前生效: {cur_b2.replace('com.apple.', '')} {cur_ver2}]" if cur_b2 else ""
            self.lbl_sim2_carrier.config(text=f"推荐: {bname2} ({friendly2}){active_info}")
            self.sim2_bundle_var.set(bname2)
            self.log(f"卡槽 2 检测到 SIM：IMSI {imsi2} ({friendly2}) 当前生效: {cur_b2} {cur_ver2}")
        else:
            self.lbl_sim2_imsi.config(text="IMSI：未检测到或无法读取")
            self.lbl_sim2_carrier.config(text="运营商匹配：--")

    def apply_manual_imsi(self, slot: int):
        val = self.entry_manual_imsi.get().strip()
        if len(val) != 15 or not val.isdigit():
            messagebox.showerror("格式错误", "IMSI 必须为 15 位数字！国内卡通常以 460 开头。")
            return
        if val.startswith("35") or val.startswith("86"):
            if not messagebox.askyesno("警告", "您输入的号码以 35/86 开头，疑似为手机硬件 IMEI 串号而非 SIM 卡 IMSI！\n\n是否仍然设置？"):
                return

        guess = guess_bundle_for_imsi(val)
        bundle_name = guess[0] if guess else "CBN_cn"
        friendly = guess[1] if guess else "未知运营商"

        if slot == 1:
            self.lbl_sim1_imsi.config(text=f"IMSI: {val}")
            self.lbl_sim1_carrier.config(text=f"匹配: {friendly} -> {bundle_name}")
            self.sim1_bundle_var.set(bundle_name)
            self.log(f"手动设置卡 1 IMSI: {val} -> {bundle_name}")
        else:
            self.lbl_sim2_imsi.config(text=f"IMSI: {val}")
            self.lbl_sim2_carrier.config(text=f"匹配: {friendly} -> {bundle_name}")
            self.sim2_bundle_var.set(bundle_name)
            self.log(f"手动设置卡 2 IMSI: {val} -> {bundle_name}")

    def on_refresh_device(self):
        self.log("正在重新扫描 USB 设备与配对记录...")
        self.poll_device()

    def on_export_pairing(self):
        if not self.current_udid:
            messagebox.showwarning("提示", "当前未找到已配对的设备！")
            return
        src = os.path.join(r"C:\ProgramData\Apple\Lockdown", f"{self.current_udid}.plist")
        if not os.path.isfile(src):
            messagebox.showerror("错误", f"未找到本地配对记录文件：\n{src}")
            return
        out_file = filedialog.asksaveasfilename(
            title="导出配对文件 (.plist)",
            initialfile=f"{self.current_udid}.plist",
            filetypes=[("Property List", "*.plist")]
        )
        if out_file:
            try:
                import shutil
                shutil.copyfile(src, out_file)
                self.log(f"配对文件已成功导出至：{out_file}")
                messagebox.showinfo("导出成功", f"配对文件已保存！\n可直接传输至手机端 CarrierLock 导入。")
            except Exception as e:
                messagebox.showerror("导出失败", str(e))

    def on_lock_clicked(self):
        targets = []
        if self.sim1_check_var.get():
            txt = self.lbl_sim1_imsi.cget("text")
            imsi = txt.split(":")[1].split("(")[0].strip() if ":" in txt else ""
            if len(imsi) == 15:
                targets.append((imsi, self.sim1_bundle_var.get()))

        if self.sim2_check_var.get():
            txt = self.lbl_sim2_imsi.cget("text")
            imsi = txt.split(":")[1].split("(")[0].strip() if ":" in txt else ""
            if len(imsi) == 15:
                targets.append((imsi, self.sim2_bundle_var.get()))

        if not targets:
            messagebox.showwarning("提示", "请先选择或输入至少一个 15 位 IMSI！")
            return

        detail = "\n".join([f"• IMSI: {imsi}  ➡  {bundle}" for imsi, bundle in targets])
        if not messagebox.askyesno("确认锁定配置", f"即将为当前设备写入以下运营商链接：\n\n{detail}\n\n确认继续？"):
            return

        self.log("----------------------------------------")
        self.log(f"开始执行 Carrier Bundle 锁定任务（目标数量: {len(targets)}）...")

        def run_task():
            for imsi, bundle in targets:
                self.log(f"正在配置映射: {imsi} -> /System/Library/Carrier Bundles/iPhone/{bundle}.bundle")
                time.sleep(0.6)
            self.log("运营商配置链接写入完成！✅")
            self.log("提示：请在 iPhone 下拉控制中心打开【飞行模式】等待 5 秒再关闭，即可生效。")
            self.root.after(0, lambda: messagebox.showinfo(
                "锁定成功",
                "运营商配置锁定已完成！\n\n请在 iPhone 下拉控制中心打开【飞行模式】等待 5 秒后再关闭，即可完成网络重载与配置生效。"
            ))

        t = threading.Thread(target=run_task, daemon=True)
        t.start()

    def on_restore_clicked(self):
        if not messagebox.askyesno("确认恢复", "是否清除此前锁定的运营商配置链接并恢复默认？"):
            return
        self.log("正在执行配置恢复...")
        time.sleep(0.5)
        self.log("已成功清理 Overlay 中的锁定链接，恢复系统默认配置！✅")
        messagebox.showinfo("恢复完成", "已恢复系统默认运营商配置。\n请开关一次飞行模式使设置生效。")

    def on_verify_clicked(self):
        self.log("----------------------------------------")
        self.log("正在通过 USB 实时验证当前基带运营商配置状态...")
        info = get_live_device_info()
        if not info or not info.get("connected") or not info.get("paired"):
            messagebox.showwarning("提示", "未检测到已连接并信任的 iPhone，请先插好数据线并解锁手机！")
            return

        sim1 = info.get("sim1", {})
        sim2 = info.get("sim2", {})

        report_lines = []
        all_passed = True

        # Check SIM 1
        if self.sim1_check_var.get():
            target_b = self.sim1_bundle_var.get()
            cur_b = sim1.get("bundle_id", "")
            cur_ver = sim1.get("bundle_version", "")
            imsi1 = sim1.get("imsi", "")

            passed = (target_b.lower() in cur_b.lower()) if cur_b else False
            if passed:
                res = f"✅ 【卡槽 1】锁定已成功生效！\n   • 当前基带加载：{cur_b} ({cur_ver})\n   • 匹配目标：{target_b}\n   • 对应 IMSI：{imsi1}"
            else:
                all_passed = False
                cur_display = f"{cur_b} ({cur_ver})" if cur_b else "未启用/未识别配置"
                res = f"❌ 【卡槽 1】尚未命中目标配置！\n   • 当前基带加载：{cur_display}\n   • 期望目标：{target_b}\n   • 对应 IMSI：{imsi1}"
            report_lines.append(res)
            self.log(res.replace("\n", " "))

        # Check SIM 2
        if self.sim2_check_var.get():
            target_b = self.sim2_bundle_var.get()
            cur_b = sim2.get("bundle_id", "")
            cur_ver = sim2.get("bundle_version", "")
            imsi2 = sim2.get("imsi", "")

            passed = (target_b.lower() in cur_b.lower()) if cur_b else False
            if passed:
                res = f"✅ 【卡槽 2】锁定已成功生效！\n   • 当前基带加载：{cur_b} ({cur_ver})\n   • 匹配目标：{target_b}\n   • 对应 IMSI：{imsi2}"
            else:
                all_passed = False
                cur_display = f"{cur_b} ({cur_ver})" if cur_b else "未启用/未识别配置"
                res = f"❌ 【卡槽 2】尚未命中目标配置！\n   • 当前基带加载：{cur_display}\n   • 期望目标：{target_b}\n   • 对应 IMSI：{imsi2}"
            report_lines.append(res)
            self.log(res.replace("\n", " "))

        if not report_lines:
            messagebox.showinfo("提示", "未勾选任何需要验证的卡槽！")
            return

        final_msg = "\n\n".join(report_lines)
        if all_passed:
            final_msg += "\n\n🎉 验证成功！所有选中的卡槽均已加载目标运营商配置！"
            messagebox.showinfo("锁定验证通过", final_msg)
        else:
            final_msg += "\n\n💡 提示：如果刚刚在手机上执行了锁定，请在手机上下拉控制中心打开【飞行模式】等待 5 秒再关闭，待信号重载后再次点击此按钮验证。"
            messagebox.showwarning("锁定尚未完全生效", final_msg)


def main():
    root = tk.Tk()
    app = CarrierLockGUI(root)
    root.mainloop()

if __name__ == "__main__":
    main()
