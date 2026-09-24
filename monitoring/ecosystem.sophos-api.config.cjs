module.exports = {
  apps: [
    {
      name: "sophos-restart-api",
      cwd: "/opt/sdrc-infrastructure/monitoring",
      script: "/opt/sdrc-infrastructure/monitoring/venv/bin/python",
      args: "sophos_api.py",
      autorestart: true,
      watch: false,
      max_restarts: 10,
      env: {
        // Fill these in directly on the deployed box, never commit real values here.
        SOPHOS_SSH_HOST: "192.168.134.1",
        SOPHOS_SSH_USER: "",
        SOPHOS_SSH_PASSWORD: "",
        SOPHOS_API_PORT: "5001"
      }
    }
  ]
};
