# Implementation Plan - Consolidated

## 🎯 Key Decisions Made

### 1. Storage: Use Existing Instance Disk (For Now)
- Store in `~/ai-teacher-storage/`
- PostgreSQL + pgvector for RAG
- Cached sections (videos/audio)
- Redis for session cache
- **Later**: Migrate to Vast.ai volume on new instance

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

**Storage Path**: `~/ai-teacher-storage/`
**Database**: PostgreSQL on localhost:5432
**Cache Check**: Before LLM/TTS/Video generation
**RAG**: ChromaDB or pgvector (TBD)

---

*All detailed plans consolidated here. Focus on implementation.*
