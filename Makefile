.PHONY: build run clean install

build:
	@chmod +x scripts/build.sh
	@./scripts/build.sh

run: build
	@open dist/YinxiangSideNotes.app

install: build
	@echo "正在安装到 /Applications/..."
	@rm -rf /Applications/YinxiangSideNotes.app
	@cp -R dist/YinxiangSideNotes.app /Applications/
	@echo "✅ 安装完成！您可以在启动台或聚焦搜索中直接打开 印象笔记 SideNotes"

clean:
	@rm -rf dist
