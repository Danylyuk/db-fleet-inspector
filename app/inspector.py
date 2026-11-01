from html import escape
from http.server import BaseHTTPRequestHandler, HTTPServer

import boto3

rds = boto3.client("rds", region_name="eu-central-1")


def check_cluster(cluster, instances):
    members = [i for i in instances
               if i["DBClusterIdentifier"] == cluster["DBClusterIdentifier"]]
    zones = {i["AvailabilityZone"] for i in members}
    return [
        ("Storage encrypted", cluster["StorageEncrypted"]),
        ("Backups kept 7+ days", cluster["BackupRetentionPeriod"] >= 7),
        ("Instances in 2+ zones", len(zones) >= 2),
        ("Not publicly accessible",
         not any(i["PubliclyAccessible"] for i in members)),
        ("Deletion protection on", cluster["DeletionProtection"]),
    ]


def render():
    clusters = rds.describe_db_clusters()["DBClusters"]
    instances = rds.describe_db_instances()["DBInstances"]
    html = "<h1>DB Fleet Inspector</h1>"
    for cluster in clusters:
        html += "<h2>" + escape(cluster["DBClusterIdentifier"]) + "</h2><ul>"
        for name, passed in check_cluster(cluster, instances):
            mark = "PASS" if passed else "FAIL"
            html += "<li>" + mark + ": " + name + "</li>"
        html += "</ul>"
    return html


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            status, body = 200, render()
        except Exception as error:
            status, body = 500, "Error: " + escape(str(error))
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(body.encode())


HTTPServer(("0.0.0.0", 80), Handler).serve_forever()
EOF