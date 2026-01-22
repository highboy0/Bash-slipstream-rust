# Slipstream Manager 🚀

![Slipstream Banner](https://via.placeholder.com/1200x400/0d1117/ffffff?text=Slipstream+DNS+Tunnel+Manager+%F0%9F%94%92+%F0%9F%9A%80)  
**اسکریپت مدیریت حرفه‌ای و گرافیکی Slipstream برای راه‌اندازی تونل DNS-based**

[![Bash](https://img.shields.io/badge/Bash-Script-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04+-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![whiptail](https://img.shields.io/badge/UI-whiptail-00A3E0?style=for-the-badge&logo=linux&logoColor=white)]()
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/Version-1.0-brightgreen?style=for-the-badge)]()

> **Slipstream Manager** یک اسکریپت هوشمند با رابط گرافیکی (whiptail) است که تمام مراحل نصب، تنظیم و مدیریت ابزار **Slipstream** را به صورت تعاملی و آسان انجام می‌دهد.  
> دیگر نیازی به تایپ دستی دستورات پیچیده نیست — همه چیز با منوهای زیبا و دیالوگ‌باکس پیش می‌رود! ✨

## ✨ ویژگی‌های کلیدی

- 🖼 **رابط گرافیکی زیبا** با whiptail (منوها، ورودی‌ها و پیام‌های دیالوگ‌باکس)
- 📥 دانلود خودکار آخرین نسخه Slipstream از GitHub
- 🔒 ساخت خودکار گواهی self-signed
- 🔓 آزادسازی خودکار پورت 53
- ⚙️ ایجاد و مدیریت سرویس systemd (اجرای دائمی + ری‌استارت خودکار)
- 💾 ذخیره تنظیمات در فایل JSON برای ویرایش آسان
- 🌐 مدیریت Resolverها (اضافه/حذف)
- 📊 نمایش وضعیت سرویس در باکس گرافیکی
- 🗑️ حذف کامل و پاک‌سازی با تأیید دو مرحله‌ای
- 🖥️ پشتیبانی کامل از سرور خارج (kharej) و سرور ایران (iran)

## 🛠 پیش‌نیازها

- سیستم‌عامل **Ubuntu 22.04 یا 24.04** (یا هر توزیع مبتنی بر Debian)
- دسترسی **root** (برای پورت 53 و systemd)
- اتصال اینترنت

پیش‌نیازهای نرم‌افزاری به صورت خودکار نصب می‌شوند:
```bash
sudo apt update && sudo apt install whiptail curl jq openssl -y 
