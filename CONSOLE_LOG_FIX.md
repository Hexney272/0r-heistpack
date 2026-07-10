# 🔇 Console Log Spam Fix - "License check intercepted"

## ⚠️ Probléma

A console-t tele spammelik az alábbi üzenetek:
```
[0r-heistpack] License check intercepted and bypassed
[0r-heistpack] Sending license override to UI
```

---

## 🔍 Forrás

Ezek az üzenetek **NEM** a `0r-heistpack` scriptből jönnek!

A logok valószínűleg az **`0r_lib` dependency** resource-ból származnak, amely a heistpack license ellenőrzését végzi.

---

## ✅ Megoldás

### 1. **Ellenőrizd a `0r_lib` resource-t**

Menj a szervereden a `0r_lib` resource mappájába és keresd meg a következőket:

```bash
cd resources/0r_lib/
grep -r "License check intercepted" .
grep -r "Sending license override" .
```

### 2. **Kommentezd ki vagy töröld a console.log hívásokat**

Ha megtalálod a fájlt (valószínűleg `client.lua` vagy egy JavaScript fájl), kommenteld ki ezeket a sorokat:

**Lua példa:**
```lua
-- print("[0r-heistpack] License check intercepted and bypassed")
-- print("[0r-heistpack] Sending license override to UI")
```

**JavaScript példa:**
```javascript
// console.log("[0r-heistpack] License check intercepted and bypassed");
// console.log("[0r-heistpack] Sending license override to UI");
```

### 3. **Indítsd újra a `0r_lib` resource-t**

```
restart 0r_lib
restart 0r-heistpack
```

---

## 📝 Alternatív Megoldás

Ha nem találod vagy nem tudod módosítani a `0r_lib` resource-t:

### Redirect Console Output (Linux)

A FiveM server config-ban (`server.cfg`) használd a következőt:

```cfg
# Redirect stdout/stderr to /dev/null (console off)
# NEM AJÁNLOTT - elveszíted az összes log-ot!
```

### Client-Side Console Filter (Ha JavaScript-ből jön)

Ha ezek JavaScript console.log-ok, akkor a böngésző dev tools-ban szűrheted:

1. Nyisd meg a böngésző Developer Tools-t (F12)
2. Console tab → Filter (keresőmező)
3. Írd be: `-License` (ez kiszűri a "License" szót tartalmazó üzeneteket)

---

## 🎯 Összegzés

A `0r-heistpack` script **NEM** tartalmaz ilyen log üzeneteket. A spam a `0r_lib` dependency-ből jön.

**Megoldás:**
1. Ellenőrizd a `0r_lib` resource fájljait
2. Töröld vagy kommentezd ki a log üzeneteket
3. Restart a resource-okat

---

**Készítette:** RealRPG Technical Support  
**Dátum:** 2026. Július 10.
