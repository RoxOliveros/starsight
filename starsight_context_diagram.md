```mermaid
%%{init: {'theme': 'neutral'}}%%
flowchart LR
    %% External Entities
    Child[Child]
    PG["Parent/Guardian<br>and Educator"]
    Firestore[Cloud Firestore]
    Gemini[Gemini API]

    %% Central Process
    StarSight((StarSight Application))

    %% Data Flows - Child
    Child -- "Gameplay Interaction<br>& Camera Feed" ---> StarSight
    StarSight -- "Learning Categories<br>& Interactive Feedback" ---> Child

    %% Data Flows - Parent/Guardian and Educator
    PG -- "Account Setup, Account Management<br>& App Configurations" ---> StarSight
    StarSight -- "Behavioral Insights<br>& Progress Reports" ---> PG

    %% Data Flows - Cloud Firestore
    StarSight -- "User Profiles &<br>AI Behavioral Metrics" ---> Firestore
    Firestore -- "Authentication &<br>Saved Analytics" ---> StarSight

    %% Data Flows - Gemini API
    StarSight -- "Raw Behavioral Metrics" ---> Gemini
    Gemini -- "Generated Narrative Summaries" ---> StarSight