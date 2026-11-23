```mermaid
%%{init: {'theme': 'neutral'}}%%
flowchart TB
    %% External Entities
    Child[Child]
    PG[Parent/Guardian<br>and Educator]
    Firestore[Cloud Firestore]
    Gemini[Gemini API]

    %% Processes
    P1((1.0<br>Account & Access<br>Management))
    P2((2.0<br>Gameplay & Category<br>Navigation))
    P3((3.0<br>AI Behavioral<br>Tracking))
    P4((4.0<br>Data Synchronization<br>& Reporting))

    %% Data Flows - Admin & Auth
    PG -- "Registration, Credentials,<br>& Profile Data" ---> P1
    P1 -- "Auth Status &<br>App Configurations" ---> PG
    
    P1 -- "Sign-in Requests &<br>Profile Updates" ---> Firestore
    Firestore -- "Auth Tokens &<br>Stored Profiles" ---> P1

    %% Data Flows - Gameplay
    Child -- "Game Interactions" ---> P2
    P2 -- "Category Levels &<br>Interactive Feedback" ---> Child

    %% Data Flows - AI Tracking
    Child -- "Real-Time<br>Camera Feed" ---> P3
    P3 -- "Gaze & Head<br>Movement Data" ---> P4

    %% Data Flows - Sync & Reporting
    P2 -- "Gameplay Progress<br>& Scores" ---> P4
    P4 -- "Behavioral Insights &<br>Progress Reports" ---> PG
    
    P4 -- "AI Metrics &<br>Game States" ---> Firestore
    Firestore -- "Saved Analytics" ---> P4

    %% Data Flows - Gemini API
    P4 -- "Raw Tracking Data" ---> Gemini
    Gemini -- "Narrative Summaries" ---> P4