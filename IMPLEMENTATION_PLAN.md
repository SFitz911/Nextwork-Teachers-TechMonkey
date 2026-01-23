# Implementation Plan - Consolidated

## 🎯 Key Decisions Made

### 1. Storage: Vast.ai Storage Volume (Persistent Volume)
- **Create Vast.ai storage volume** when launching new instance
- **Attach volume to instance** (mounts at `/mnt/vast-storage/` or similar)
- PostgreSQL + pgvector data stored on volume
- Cached sections (videos/audio) stored on volume
- **No Redis** - using PostgreSQL + Vast.ai storage volume
- **Persistent** - survives instance restarts, can detach/reattach

### 2. Database: PostgreSQL + pgvector (Self-hosted)
- No Supabase Cloud (keep everything on instance)
- pgvector extension for embeddings
- Store: sessions, sections, embeddings, clips

### 3. Caching: Content Hash Based
- Same content + language + teacher = reuse cached video
- Store: video.mp4, audio.wav, metadata.json
- Path: `~/ai-teacher-storage/cached_sections/{session_id}/{section_id}/`

### 4. RAG System: Automatic Page Segmentation
- Auto-split page into sections (left-to-right, top-to-bottom)
- Round-robin: Left teacher (odd), Right teacher (even)
- Pre-process all sections, store in RAG
- Retrieve context as user scrolls

---

## 🚀 Next Steps (Implementation Order)

1. **Create new Vast.ai instance** with storage volume (200-500 GB recommended)
2. **Attach volume to instance** (will auto-mount or mount manually)
3. **Set up storage directories** on volume (`/mnt/vast-storage/`)
4. **Install PostgreSQL + pgvector** on instance
5. **Configure PostgreSQL** to use volume for data directory
6. **Create database schema** (sessions, sections, embeddings, processed_sections)
7. **Update Coordinator API** to use database
8. **Implement caching** (check before processing, store on volume)
9. **Add page segmentation** service
10. **Implement RAG** with vector search

---

## 📝 Quick Reference

**Storage Path**: `/mnt/vast-storage/` (Vast.ai storage volume - persistent)
**Database**: PostgreSQL on Vast.ai instance (localhost:5432), data on volume
**Cache Check**: Before LLM/TTS/Video generation
**RAG**: pgvector (PostgreSQL extension)
**Setup**: Create volume when launching new instance, attach to instance

---

*All detailed plans consolidated here. Focus on implementation.*
