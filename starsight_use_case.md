```mermaid
%%{init: {'theme': 'neutral'}}%%
flowchart LR
    PG(((Parent/Guardian<br> and Educator)))
    Child(((Child)))
    Firestore(((Cloud Firestore)))
    Gemini(((Gemini API)))

    subgraph StarSight["StarSight Educational System Boundary"]

        subgraph Auth ["Authentication"]
            direction TB
            UC_SignUp([Sign Up / Create Account])
            UC_SignIn([Sign In / Authenticate])
            UC_Reset([Reset Password])
            UC_PIN([Verify PIN])
        end

        subgraph PGArea ["Account & Profile Management"]
            direction TB
            Spacer1[" "]:::hidden
            Spacer1 ~~~ UC_Manage
            UC_Manage([Manage Child Profiles])
            UC_Limits([Set Screen Time Limits])
            UC_Reports([View AI Progress Reports])
        end

        subgraph Gameplay ["Child Experience"]
            direction TB
            UC_Calibrate([Calibrate AI Camera])
            UC_Nav([Navigate Category Levels])
            UC_Play([Play Educational Minigames])
        end

        subgraph Services ["Background Services"]
            direction TB
            UC_Vision([Track Gaze & Head Movements])
            UC_Lock([Enforce Screen Time Lock])
            UC_Data([Generate Behavioral Insights])
            UC_Sync([Sync Game Progress])
        end
    end

    classDef hidden fill:none,stroke:none,color:none;

    %% Parent/Guardian and Educator Relationships
    PG --> UC_SignUp
    PG --> UC_SignIn
    PG --> UC_Reset
    PG --> UC_Manage
    PG --> UC_Limits
    PG --> UC_Reports

    %% Access Control Dependencies
    UC_Manage -.->|"<< includes >>\nRequires PIN"| UC_PIN
    UC_Limits -.->|"<< includes >>\nRequires PIN"| UC_PIN
    UC_Reports -.->|"<< includes >>\nRequires PIN"| UC_PIN
    UC_Lock -.->|"<< extends >>\nAdult can override"| UC_PIN

    %% Child Relationships
    Child -->|Completes setup| UC_Calibrate
    Child -->|Browses| UC_Nav
    Child -->|Plays| UC_Play

    %% Gameplay Dependencies
    UC_Play -.->|"<< includes >>\nTracks gaze/head"| UC_Vision
    UC_Play -.->|"<< includes >>\nChecks time"| UC_Lock
    UC_Nav -.->|"<< includes >>\nFetches stars"| UC_Sync

    %% System Actor Relationships
    Firestore --> UC_Vision
    Firestore --> UC_Lock
    Firestore --> UC_Sync
    Gemini --> UC_Data

    %% AI Report Dependency
    UC_Reports -.->|"<< includes >>\nFormats AI data"| UC_Data