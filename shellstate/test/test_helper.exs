ExUnit.start()

# Add test support files
ExUnit.configure(
  trace: true,
  colour: true,
  timeout: 10_000
)

# Clean up test directories
File.rm_rf!("test/tmp")
File.mkdir_p!("test/tmp")