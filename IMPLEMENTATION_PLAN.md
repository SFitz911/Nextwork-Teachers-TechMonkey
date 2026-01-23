# Implementation Plan - Consolidated

## 🎯 Key Decisions Made

### 1. Storage: On Vast.ai Instance (Local to Instance)
- **All storage is on the Vast.ai instance** (not your desktop)
- Store in `~/ai-teacher-storage/` on Vast.ai instance
- PostgreSQL + pgvector for RAG (runs on Vast.ai instance)
- Cached sections (videos/audio) stored on Vast.ai instance disk
- **No Redis** - using PostgreSQL + instance disk storage
- **Later**: Can migrate to Vast.ai volume if needed

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

1. **Set up storage directories** on existing instance
2. **Install PostgreSQL + pgvector**
3. **Create database schema** (sessions, sections, embeddings, processed_sections)
4. **Update Coordinator API** to use database
5. **Implement caching** (check before processing)
6. **Add page segmentation** service
7. **Implement RAG** with vector search

---

## 📝 Quick Reference

**Storage Path**: `~/ai-teacher-storage/` (on Vast.ai instance)
**Database**: PostgreSQL on Vast.ai instance (localhost:5432)
**Cache Check**: Before LLM/TTS/Video generation
**RAG**: pgvector (PostgreSQL extension)
**Location**: Everything runs on Vast.ai instance - no external cloud storage

---

*All detailed plans consolidated here. Focus on implementation.*
