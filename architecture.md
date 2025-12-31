# SIMPLAW - Architecture Plan

## App Overview
SIMPLAW is a voice-first document simplification app that transforms complex legal, financial, and bureaucratic documents into clear, human-readable explanations with natural voice narration.

## Core Features (MVP)
1. **Document Input**
   - Text paste functionality
   - PDF/text file upload
   - Clean, trust-first upload interface

2. **Configuration Options**
   - Language selection for explanation
   - Voice tone selection (Calm / Professional / Friendly)

3. **AI Processing**
   - OpenAI GPT-4 for document analysis and simplification
   - Structured output generation

4. **Voice Narration**
   - ElevenLabs voice synthesis
   - Prominent audio player with play/pause controls
   - 20-60 second audio explanations

5. **Structured Explanation Display**
   - Document Type identification
   - Simple Explanation (plain language)
   - Action Required (Yes/No)
   - Deadline detection
   - Risk Level (Low/Medium/High)
   - Suggested Next Steps

6. **Legal Disclaimer**
   - Clear disclaimer that SIMPLAW doesn't provide legal advice

## Technical Architecture

### Data Models (`lib/models/`)
1. **DocumentAnalysis** - Stores the AI-generated analysis
   - documentType: String
   - simpleExplanation: String
   - actionRequired: bool
   - deadline: String?
   - riskLevel: String (Low/Medium/High)
   - suggestedNextStep: String
   - audioUrl: String?
   - createdAt: DateTime

2. **User** - Basic user tracking
   - id: String
   - name: String
   - email: String
   - createdAt: DateTime

### Services (`lib/services/`)
1. **OpenAIService** - Document analysis and simplification
2. **ElevenLabsService** - Text-to-speech voice generation
3. **DocumentAnalysisService** - Manages analysis records (local storage)

### Screens (`lib/screens/`)
1. **HomePage** - Landing screen with upload/paste interface
2. **ResultsPage** - Displays analysis with audio player and structured explanation

### Components (`lib/components/`)
1. **DocumentUploader** - Upload/paste interface component
2. **AudioPlayer** - Custom audio player with prominent controls
3. **ExplanationCard** - Structured information display
4. **DisclaimerBanner** - Legal disclaimer component
5. **LanguageSelector** - Language selection dropdown
6. **VoiceToneSelector** - Voice tone selection (Calm/Professional/Friendly)

### UI/UX Design
- **Color Palette**: Sophisticated Monochrome approach
  - Light: Pure white backgrounds, soft blue-grey accents, deep blue primary
  - Dark: Deep blue-charcoal base with blue-grey elevations
  - Accent: Deep blue (#2563EB) for trust and professionalism
- **Typography**: Inter font family (clean, professional)
- **Layout**: Card-based, generous spacing, mobile-first responsive
- **No Material Design**: Custom flat design with subtle borders

### Navigation
- `/` - HomePage (upload interface)
- `/results` - ResultsPage (analysis display)

## Implementation Steps
1. ✅ Create architecture.md
2. Update theme with trust-first color palette
3. Create data models
4. Create OpenAI service for document analysis
5. Create ElevenLabs service for voice synthesis
6. Create local storage service for analysis history
7. Build HomePage with upload/paste interface
8. Build configuration selectors (language, voice tone)
9. Build ResultsPage with audio player and explanation cards
10. Add disclaimer banner
11. Implement navigation flow
12. Add dependencies and compile project
13. Test and debug

## Key Design Decisions
- **No backend required**: Uses local storage for analysis history
- **Voice-first UX**: Audio player is the primary output
- **Trust-first design**: Clean, professional, calming aesthetic
- **Mobile-first**: Optimized for mobile but works on web
- **Demo-ready**: Complete flow under 60 seconds
