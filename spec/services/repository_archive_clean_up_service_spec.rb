require 'spec_helper'

describe RepositoryArchiveCleanUpService, services: true do
  describe '#execute' do
    let(:path) { File.join(Rails.root, 'tmp/tests/shared/cache/archive') }

    subject(:service) { described_class.new }

    before do
      allow(Gitlab.config.gitlab).to receive(:repository_downloads_path).and_return(path)
    end

    context 'when the downloads directory does not exist' do
      it 'does not remove any archives' do
        expect(File).to receive(:directory?).with(path).and_return(false)
        expect(service).not_to receive(:clean_up_old_archives)
        expect(service).not_to receive(:clean_up_empty_directories)

        service.execute
      end
    end

    context 'when the downloads directory exists' do
      before do
        FileUtils.mkdir_p(path)
      end

      after do
        FileUtils.rm_rf(path)
      end

      context 'when archives older than 2 hours exists' do
        it 'removes old files that matches valid archive extensions' do
          dirname = File.join(path, 'sample.git')
          files = create_temporary_files(dirname, %w[tar tar.bz2 tar.gz zip], 2.hours)

          service.execute

          files.each { |file| expect(File.exist?(file)).to eq false }
          expect(File.directory?(dirname)).to eq false
        end

        it 'keeps old files that does not matches valid archive extensions' do
          dirname = File.join(path, 'sample.git')
          files = create_temporary_files(dirname, %w[conf rb], 2.hours)

          service.execute

          files.each { |file| expect(File.exist?(file)).to eq true }
          expect(File.directory?(dirname)).to eq true
        end

        it 'keeps old files inside invalid directories' do
          dirname = File.join(path, 'john_doe/sample.git')
          files = create_temporary_files(dirname, %w[conf rb tar tar.gz], 2.hours)

          service.execute

          files.each { |file| expect(File.exist?(file)).to eq true }
          expect(File.directory?(dirname)).to eq true
        end
      end

      context 'when archives older than 2 hours does not exist' do
        it 'keeps files that matches valid archive extensions' do
          dirname = File.join(path, 'sample.git')
          files = create_temporary_files(dirname, %w[tar tar.bz2 tar.gz zip], 1.hour)

          service.execute

          files.each { |file| expect(File.exist?(file)).to eq true }
          expect(File.directory?(dirname)).to eq true
        end

        it 'keeps files that does not matches valid archive extensions' do
          dirname = File.join(path, 'sample.git')
          files = create_temporary_files(dirname, %w[conf rb], 1.hour)

          service.execute

          files.each { |file| expect(File.exist?(file)).to eq true }
          expect(File.directory?(dirname)).to eq true
        end

        it 'keeps files inside invalid directories' do
          dirname = File.join(path, 'john_doe/sample.git')
          files = create_temporary_files(dirname, %w[conf rb tar tar.gz], 1.hour)

          service.execute

          files.each { |file| expect(File.exist?(file)).to eq true }
          expect(File.directory?(dirname)).to eq true
        end
      end

      def create_temporary_files(dirname, extensions, mtime)
        FileUtils.mkdir_p(dirname)
        FileUtils.touch(extensions.map { |ext| File.join(dirname, "sample.#{ext}") }, mtime: Time.now - mtime)
      end
    end
  end
end
