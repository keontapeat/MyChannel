# 🔥 **RUN THIS EXACT COMMAND IN YOUR TERMINAL**

```bash
firebase login --reauth
```

**This will**:
1. Open a browser window
2. Ask you to sign in with Google (keontapeat@mychannel.live)
3. Authorize Firebase CLI
4. Return to terminal

**Then run**:
```bash
firebase deploy --only firestore:indexes --project mychannel-ca26d
```

---

## ⚡ **OR RUN BOTH AT ONCE:**

```bash
firebase login --reauth && firebase deploy --only firestore:indexes --project mychannel-ca26d
```

---

**DO IT NOW!** 🚀

