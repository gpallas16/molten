# Liquid Glass Plugin for Hyprland
# Apple-style liquid glass effect with refraction, chromatic aberration, and Fresnel highlights

ifeq ($(CXX),g++)
    EXTRA_FLAGS = --no-gnu-unique
else
    EXTRA_FLAGS =
endif

CXXFLAGS = -shared -fPIC -g -std=c++2b
INCLUDES = `pkg-config --cflags pixman-1 libdrm hyprland pangocairo libinput libudev wayland-server xkbcommon`
LIBS = `pkg-config --libs pangocairo`

SRC = src/main.cpp src/LiquidGlassDecoration.cpp src/LiquidGlassPassElement.cpp
TARGET = liquid-glass.so

# Shader embedding
SHADERS_DIR = shaders
SHADERS_OUTPUT = src/shaders.hpp
SHADER_FILES = $(wildcard $(SHADERS_DIR)/*.frag)

all: $(SHADERS_OUTPUT) $(TARGET)

$(SHADERS_OUTPUT): $(SHADER_FILES)
	@echo "Embedding shaders..."
	@echo "// Auto-generated shader header - Do not edit!" > $(SHADERS_OUTPUT)
	@echo "#pragma once" >> $(SHADERS_OUTPUT)
	@echo "" >> $(SHADERS_OUTPUT)
	@echo "#include <unordered_map>" >> $(SHADERS_OUTPUT)
	@echo "#include <string>" >> $(SHADERS_OUTPUT)
	@echo "" >> $(SHADERS_OUTPUT)
	@echo "inline const std::unordered_map<std::string, const char*> SHADERS = {" >> $(SHADERS_OUTPUT)
	@for shader in $(SHADER_FILES); do \
		name=$$(basename $$shader); \
		echo "    {\"$$name\", R\"GLSL(" >> $(SHADERS_OUTPUT); \
		cat $$shader >> $(SHADERS_OUTPUT); \
		echo ")GLSL\"}," >> $(SHADERS_OUTPUT); \
	done
	@echo "};" >> $(SHADERS_OUTPUT)
	@echo "Shaders embedded successfully."

$(TARGET): $(SRC) $(SHADERS_OUTPUT)
	@echo "Building $(TARGET)..."
	$(CXX) $(CXXFLAGS) $(EXTRA_FLAGS) $(INCLUDES) $(SRC) -o $@ $(LIBS) -O2
	@echo "Build complete: $(TARGET)"

clean:
	rm -f $(TARGET) $(SHADERS_OUTPUT)

.PHONY: all clean
