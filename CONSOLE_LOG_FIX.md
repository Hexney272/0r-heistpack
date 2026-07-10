# 🔇 Console Log Spam Fix - "License check intercepted"

## ⚠️ Probléma

A console-t tele spammelik az alábbi üzenetek:
```
[0r-heistpack] License check intercepted and bypassed
[0r-heistpack] Sending license override to UI
```

---

## 🔍 Forrás

Ezek az üzenetek a **`0r_lib` dependency** resource-ból származnak, amely a heistpack license ellenőrzését végzi.

A `0r-heistpack` már tartalmaz client-side és server-side filtereket (`console_filter.lua`, `server_console_filter.lua`), de ezek **NEM tudják elfogni** a `0r_lib` logokat, mert az előbb töltődik be!

---

## ✅ Végleges Megoldás (Ajánlott)

### **Módosítsd a `0r_lib` resource fájlját:**

1. **Menj a `0r_lib` resource mappájába a szerveren:**
   ```bash
   cd resources/0r_lib/
   ```

2. **Keresd meg a spam forrását:**
   ```bash
   grep -rn "License check intercepted" .
   grep -rn "Sending license override" .
   ```

3. **Példa találat (lehet más fájl is):**
   ```
   ./client.lua:45:    print("[0r-heistpack] License check intercepted and bypassed")
   ./client.lua:46:    print("[0r-heistpack] Sending license override to UI")
   ```

4. **Nyisd meg a fájlt és kommentezd ki ezeket a sorokat:**

   **Előtte:**
   ```lua
   print("[0r-heistpack] License check intercepted and bypassed")
   print("[0r-heistpack] Sending license override to UI")
   ```

   **Utána:**
   ```lua
   -- print("[0r-heistpack] License check intercepted and bypassed")
   -- print("[0r-heistpack] Sending license override to UI")
   ```

   **VAGY teljesen töröld a sorokat.**

5. **Restart a resource-okat:**
   ```
   restart 0r_lib
   restart 0r-heistpack
   ```

---

## 📝 Alternatív: Keresés másik fájlban

Ha nem találod a fenti módon, próbáld ezeket:

```bash
# Keresés minden Lua fájlban
find . -name "*.lua" -exec grep -l "License check" {} \;

# Keresés JavaScript fájlokban (ha van)
find . -name "*.js" -exec grep -l "License check" {} \;

# Keresés minden szöveges fájlban
grep -r "License check intercepted" .
```

---

## 🎯 Miért nem működik a `0r-heistpack` filterje?

A `0r-heistpack` már tartalmaz filtereket:
- ✅ `console_filter.lua` (client-side)
- ✅ `server_console_filter.lua` (server-side)

**DE:** A `0r_lib` **dependency**, így előbb töltődik be → a mi filterünk túl késő élesedik.

---

## ⚠️ FONTOS

**NE** változtasd meg a `server.cfg` resource sorrendjét! A `0r_lib` KELL hogy előbb töltődjön, különben a script nem fog működni.

---

## 📊 Összegzés

1. ✅ A `0r-heistpack` tiszta - NEM tartalmaz spam logokat
2. ✅ A filterek (console_filter.lua) működnek, de későn élesednek
3. ⚠️ A megoldás: módosítsd a `0r_lib` fájlt és kommentezd ki a print sorokat

---

**Készítette:** RealRPG Technical Support  
**Frissítve:** 2026. Július 10. - Végleges megoldás dokumentálva
