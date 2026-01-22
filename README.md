# Slipstream Manager 🚀

![Slipstream Banner](https://via.placeholder.com/1200x600/0d1117/ffffff?text=Slipstream+DNS+Tunnel+Manager+%F0%9F%94%92+%F0%9F%9A%80)  
*اسکریپت حرفه‌ای مدیریت Slipstream با رابط گرافیکی تعاملی (whiptail)*

[![Bash Script](https://img.shields.io/badge/Bash-Script-89e051?style=flat&logo=gnu-bash&logoColor=black)](https://www.gnu.org/software/bash/)
[![Ubuntu Compatible](https://img.shields.io/badge/Ubuntu-22.04%2B-E95420?style=flat&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Whiptail UI](https://img.shields.io/badge/UI-Whiptail-4ECDC4?style=flat&logo=linux&logoColor=white)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Stars](https://img.shields.io/github/stars/highboy0/Bash-slipstream-rust?style=social)]()
[![Forks](https://img.shields.io/github/forks/highboy0/Bash-slipstream-rust?style=social)]()

> **Slipstream Manager** یک اسکریپت کاملاً تعاملی و زیبا برای نصب، تنظیم، مدیریت و حذف ابزار **Slipstream** (تونل DNS-based برای) است.  
> با این اسکریپت دیگر نیازی به تایپ دستورات پیچیده نیست — همه چیز با منوهای گرافیکی داخل ترمینال انجام می‌شود!

### ✨ ویژگی‌های کلیدی
- 🖼 **رابط گرافیکی زیبا** با `whiptail` (دیالوگ‌باکس‌های حرفه‌ای)
- 📥 دانلود خودکار آخرین نسخه Slipstream از GitHub
- 🔐 ساخت خودکار گواهی self-signed
- 🚪 آزادسازی خودکار پورت 53
- ⚙️ ایجاد و مدیریت سرویس **systemd** (اجرای دائمی + ری‌استارت خودکار)
- 💾 ذخیره تنظیمات در فایل JSON (`/opt/slipstream/config.ini`)
- 🔄 مدیریت Resolverها (اضافه/حذف)
- 📊 نمایش وضعیت سرویس در باکس گرافیکی
- 🗑 حذف کامل و پاک‌سازی ایمن
- 🌍 پشتیبانی کامل از **سرور خارج (kharej)** و **سرور ایران (iran)**

---

### ⚡ شروع سریع (Quick Start)

```bash
git clone https://github.com/highboy0/Bash-slipstream-rust.git && cd Bash-slipstream-rust && sudo chmod +x slipstream-manager.sh && sudo ./slipstream-manager.sh

