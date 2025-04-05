import psutil
import dash
from dash import dcc, html
from dash.dependencies import Input, Output
import time
import plotly.graph_objects as go
import os

# Initialize the Dash app
app = dash.Dash(__name__)
server = app.server

# Define custom styles
main_bg_color = "#1e1e2e"
card_bg_color = "#252b3b"
text_color = "#f8f9fa"
highlight_color = "#04d9ff"

# Function to simulate different system loads based on profile & user count
def apply_stress(profile, user_count):
    multiplier = user_count // 100  

    if profile == "CPUHeavy":
        for _ in range(multiplier * 5):
            _ = [x**2 for x in range(10000)]
    
    elif profile == "MemHeavy":
        _ = [bytearray(10000000) for _ in range(multiplier)]

    elif profile == "DiskHeavy":
        with open("/tmp/disk_stress_test", "wb") as f:
            f.write(os.urandom(multiplier * 10 * 1024 * 1024))

    elif profile == "ThruputHeavy":
        time.sleep(0.1 * multiplier)

# Function to fetch system metrics
def get_metrics(profile="GeneralPurpose", user_count=100):
    apply_stress(profile, user_count)

    return {
        "cpu_usage": psutil.cpu_percent(interval=1),
        "memory": {
            "total": psutil.virtual_memory().total / (1024 * 1024),
            "used": psutil.virtual_memory().used / (1024 * 1024),
            "available": psutil.virtual_memory().available / (1024 * 1024),
            "percent": psutil.virtual_memory().percent
        },
        "disk": {
            "total": psutil.disk_usage('/').total / (1024 * 1024 * 1024),
            "used": psutil.disk_usage('/').used / (1024 * 1024 * 1024),
            "free": psutil.disk_usage('/').free / (1024 * 1024 * 1024),
            "percent": psutil.disk_usage('/').percent
        },
        "network": {
            "bytes_sent": psutil.net_io_counters().bytes_sent / (1024 * 1024),
            "bytes_received": psutil.net_io_counters().bytes_recv / (1024 * 1024)
        }
    }

# Layout of the Dashboard
app.layout = html.Div(
    style={'backgroundColor': main_bg_color, 'color': text_color, 'padding': '20px'},
    children=[
        html.H1("Ubuntu VM Performance Dashboard", style={'textAlign': 'center', 'color': highlight_color}),

        # Profile Selection with Improved Visibility
        html.Div([
            html.Label("Select Profile:", style={'fontSize': '22px', 'fontWeight': 'bold', 'display': 'block', 'marginBottom': '10px'}),
            dcc.Dropdown(
                id='profile-dropdown',
                options=[
                    {'label': 'CPU Heavy', 'value': 'CPUHeavy'},
                    {'label': 'Memory Heavy', 'value': 'MemHeavy'},
                    {'label': 'Disk Heavy', 'value': 'DiskHeavy'},
                    {'label': 'Throughput Heavy', 'value': 'ThruputHeavy'},
                    {'label': 'General Purpose', 'value': 'GeneralPurpose'}
                ],
                value='GeneralPurpose',
                style={'width': '60%', 'fontSize': '18px', 'padding': '10px', 'backgroundColor': '#fff', 'color': '#000'}
            )
        ], style={'textAlign': 'center', 'marginBottom': '20px'}),

        # User Count Selection
        html.Div([
            html.Label("Number of Users:", style={'fontSize': '22px', 'fontWeight': 'bold', 'display': 'block', 'marginBottom': '10px'}),
            dcc.Slider(
                id='user-slider',
                min=100,
                max=100000,
                step=100,
                marks={100: '100', 1000: '1K', 5000: '5K', 10000: '10K', 100000: '100K'},
                value=100
            )
        ], style={'textAlign': 'center', 'width': '80%', 'margin': 'auto'}),

        html.Br(),

        html.Div([
            html.Div([html.H3("CPU Usage", style={'textAlign': 'center'}), dcc.Graph(id='cpu-gauge')],
                     style={'width': '48%', 'display': 'inline-block', 'padding': '10px', 'backgroundColor': card_bg_color, 'borderRadius': '15px'}),

            html.Div([html.H3("Memory Usage", style={'textAlign': 'center'}), dcc.Graph(id='memory-graph')],
                     style={'width': '48%', 'display': 'inline-block', 'padding': '10px', 'backgroundColor': card_bg_color, 'borderRadius': '15px'})
        ], style={'display': 'flex', 'justifyContent': 'space-between'}),

        html.Br(),

        html.Div([
            html.Div([html.H3("Disk Usage", style={'textAlign': 'center'}), dcc.Graph(id='disk-graph')],
                     style={'width': '48%', 'display': 'inline-block', 'padding': '10px', 'backgroundColor': card_bg_color, 'borderRadius': '15px'}),

            html.Div([html.H3("Network Traffic", style={'textAlign': 'center'}), dcc.Graph(id='network-graph')],
                     style={'width': '48%', 'display': 'inline-block', 'padding': '10px', 'backgroundColor': card_bg_color, 'borderRadius': '15px'})
        ], style={'display': 'flex', 'justifyContent': 'space-between'}),

        dcc.Interval(id='interval-component', interval=5000, n_intervals=0)
    ]
)

# CPU Usage Gauge
@app.callback(Output('cpu-gauge', 'figure'), Input('interval-component', 'n_intervals'), Input('profile-dropdown', 'value'), Input('user-slider', 'value'))
def update_cpu_gauge(n, profile, user_count):
    metrics = get_metrics(profile, user_count)
    fig = go.Figure(go.Indicator(
        mode="gauge+number",
        value=metrics['cpu_usage'],
        title={'text': f"CPU Usage (%) - {profile} ({user_count} users)"},
        gauge={'axis': {'range': [0, 100]}, 'bar': {'color': highlight_color}}
    ))
    return fig

# Memory Usage
@app.callback(Output('memory-graph', 'figure'), Input('interval-component', 'n_intervals'), Input('profile-dropdown', 'value'), Input('user-slider', 'value'))
def update_memory_graph(n, profile, user_count):
    metrics = get_metrics(profile, user_count)
    fig = go.Figure([
        go.Bar(name='Used', x=['Memory'], y=[metrics['memory']['used']], marker_color='red'),
        go.Bar(name='Available', x=['Memory'], y=[metrics['memory']['available']], marker_color='green')
    ])
    fig.update_layout(barmode='stack', title=f"Memory Usage (MB) - {profile} ({user_count} users)")
    return fig

# Disk Usage
@app.callback(Output('disk-graph', 'figure'), Input('interval-component', 'n_intervals'), Input('profile-dropdown', 'value'), Input('user-slider', 'value'))
def update_disk_graph(n, profile, user_count):
    metrics = get_metrics(profile, user_count)
    fig = go.Figure([
        go.Bar(name='Used', x=['Disk'], y=[metrics['disk']['used']], marker_color='orange'),
        go.Bar(name='Free', x=['Disk'], y=[metrics['disk']['free']], marker_color='blue')
    ])
    fig.update_layout(barmode='stack', title=f"Disk Usage (GB) - {profile} ({user_count} users)")
    return fig

# Run the app
if __name__ == '__main__':
    app.run_server(debug=True, host='0.0.0.0', port=8050)
