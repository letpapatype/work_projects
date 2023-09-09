# # TODO: Pass in the BuildArchive path to generate a release number programmatically
from azure.devops.connection import Connection
from msrest.authentication import BasicAuthentication
from azure.devops.v6_0.work_item_tracking.models import Wiql
import pprint
import os
import requests

# Fill in with your personal access token and org URL
# To run locally, be sure to set variables for $env:pat (TFS personal access token), $env:Product ('Fulfillment 17.10 - Release' for example) and a $env:BuildArchive (The location of the release builds)
personal_access_token = os.getenv("pat")
tfs = 'http://i*****:8080/tfs/defaultcollection'
discipline = os.getenv("PRODUCT")
build_archive = os.getenv("BuildArchive")
target_build = discipline.split(' ')[1]
    
# generate release number 
folders = [f for f in os.listdir(build_archive) if os.path.isdir(os.path.join(build_archive, f))]
folders.sort(key=lambda x: os.path.getmtime(os.path.join(build_archive, x)), reverse=True)
most_recent_folder = folders[0]
release_number = most_recent_folder.split(' ')[-1]
target_build = discipline.split(' ')[1]
# To test release_number print(f"The release number is: {release_number}")

# This function will take a WI passed in from the code_reviewed_query, and update the State, along with the Test Build number
def update_work_items_ready_for_test():
    work_item_to_update_url = f'http://***:8080/tfs/defaultcollection/_apis/wit/workitems/{code_reviewed.id}?api-version=4.1'
    data = [
    {
        "op": "add",
        "path": "/fields/System.State",
        "value": "Ready for Test"
    },
    {
        "op": "add",
        "path": "/fields/User.TestBuild",
        "value": release_number
    }
    ]

    r = requests.patch(work_item_to_update_url, json=data,
                   headers={'Content-Type': 'application/json-patch+json'},
                   auth=('', personal_access_token))

    print(f"{code_reviewed.id} is updated to 'Ready for Test'")

# This function updates the 'Code Complete' work items' 'Test Build' number for QA
def update_code_complete_test_build():
    work_item_to_update_url = f'http://****:8080/tfs/defaultcollection/_apis/wit/workitems/{needs_code_review.id}?api-version=4.1'
    data = [
    {
        "op": "add",
        "path": "/fields/User.TestBuild",
        "value": release_number
    }
    ]

    r = requests.patch(work_item_to_update_url, json=data,
                   headers={'Content-Type': 'application/json-patch+json'},
                   auth=('', personal_access_token))

def update_wis_in_review():
    work_item_to_update_url = f'http://iaswtfs18:8080/tfs/defaultcollection/_apis/wit/workitems/{review_in_progress.id}?api-version=4.1'
    data = [
    {
        "op": "add",
        "path": "/fields/User.TestBuild",
        "value": release_number
    }
    ]

    r = requests.patch(work_item_to_update_url, json=data,
                   headers={'Content-Type': 'application/json-patch+json'},
                   auth=('', personal_access_token))

# Setting connections to TFS, along with the query 
print("Starting Work Item review. Connecting to Azure Devops Server (TFS)...")
# Create a connection to the org
credentials = BasicAuthentication('', personal_access_token)
connection = Connection(base_url=tfs, creds=credentials)
# Query
code_complete_query = Wiql(query=f"SELECT [ID], [Title], [State] FROM workitems WHERE [State] = 'Code Complete' AND [Test Build] = '' AND ([Discipline] Contains '{discipline}' OR [Target Build] Contains '{target_build}')")
code_reviewed_query = Wiql(query=f"SELECT [ID], [Title], [State] FROM workitems WHERE [State] = 'Code Reviewed' AND [Test Build] = '' AND ([Discipline] Contains '{discipline}' OR [Target Build] Contains '{target_build}')")
code_review_in_prog_query = Wiql(query=f"SELECT [ID], [Title], [State] FROM workitems WHERE [State] = 'Code Review In Progress' AND [Test Build] = '' AND ([Discipline] Contains '{discipline}' OR [Target Build] Contains '{target_build}')")
# Get a reference to the WorkItemTrackingClient
wit_client = connection.clients.get_work_item_tracking_client()

# Execute the query and get the result
print("Quering work items for 'Code Reviewed' and 'Code Complete' states...")
wis_in_code_complete = wit_client.query_by_wiql(code_complete_query)
wis_in_code_reviewed = wit_client.query_by_wiql(code_reviewed_query)
wis_review_in_progress = wit_client.query_by_wiql(code_review_in_prog_query)
print("The work items states are as follows...")

for review_in_progress in wis_review_in_progress.work_items:
    print(f"Work Item: {review_in_progress.id} is currently being reviewed, and has had it's 'Test Build' updated.")
    update_wis_in_review()

print(f"The work items currently being reviewed has had their 'Test Build' updated to: {release_number}")

for needs_code_review in wis_in_code_complete.work_items:
    print(f"Work Item: {needs_code_review.id} needs to be Code Reviewed.")
    update_code_complete_test_build()

print(f"The work items in 'Code Complete' have had their 'Test Build' updated to: {release_number}")

for code_reviewed in wis_in_code_reviewed.work_items:
    print(f"Work Item: {code_reviewed.id} has been Code Reviewed and is being updated to 'Ready for Test'")
    # Run the wi update
    update_work_items_ready_for_test()
    # Print Updated to ready for test for TestBuild work item

print(f"The work items are in 'Ready for Test' and ready for Test Build: {release_number}")
print("Work Item review is complete.")
