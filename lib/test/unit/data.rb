module Test
  module Unit
    module Data
      class << self
        def included(base)
          base.extend(ClassMethods)
        end
      end

      module ClassMethods
        # This method provides Data-Driven-Test functionality.
        #
        # Define test data in the test code.
        #
        # @overload data(label, data)
        #   @param [String] label specify test case name.
        #   @param data specify test data.
        #
        #   @example data(label, data)
        #     data("empty string", [true, ""])
        #     data("plain string", [false, "hello"])
        #     def test_empty?(data)
        #       expected, target = data
        #       assert_equal(expected, target.empty?)
        #     end
        #
        # @overload data(data_set)
        #   @param [Hash] data_set specify test data as a Hash that
        #     key is test label and value is test data.
        #
        #   @example data(data_set)
        #     data("empty string" => [true, ""],
        #          "plain string" => [false, "hello"])
        #     def test_empty?(data)
        #       expected, target = data
        #       assert_equal(expected, target.empty?)
        #     end
        #
        # @overload data(&block)
        #   @yieldreturn [Hash] return test data set as a Hash that
        #     key is test label and value is test data.
        #
        #   @example data(&block)
        #     data do
        #       data_set = {}
        #       data_set["empty string"] = [true, ""]
        #       data_set["plain string"] = [false, "hello"]
        #       data_set
        #     end
        #     def test_empty?(data)
        #       expected, target = data
        #       assert_equal(expected, target.empty?)
        #     end
        #
        def data(*arguments, &block)
          n_arguments = arguments.size
          case n_arguments
          when 0
            raise ArgumentError, "no block is given" unless block_given?
            data_set = block
          when 1
            data_set = arguments[0]
          when 2
            data_set = {arguments[0] => arguments[1]}
          else
            message = "wrong number arguments(#{n_arguments} for 1..2)"
            raise ArgumentError, message
          end
          current_data = current_attribute(:data)[:value] || []
          attribute(:data, current_data + [data_set])
        end

        # This method provides Data-Driven-Test functionality.
        #
        # Load test data from the file. This is short hand to load
        # test data from file.  If you want to load complex file, you
        # can use {#data} with block.
        #
        # @param [String] file_name full path to test data file.
        #   File format is automatically detected from filename extension.
        # @raise [ArgumentError] if +file_name+ is not supported file format.
        # @see CSVDataLoader
        #
        # @example Load data from CSV file
        #   load_data("/path/to/test-data.csv")
        #   def test_empty?(data)
        #     assert_equal(data["expected"], data["target"].empty?)
        #   end
        #
        def load_data(file_name)
          case File.extname(file_name).downcase
          when ".csv"
            loader = Loader.new(self)
            loader.load(file_name)
          else
            raise ArgumentError, "unsupported file format: <#{file_name}>"
          end
        end

        # Load data from CSV file.
        #
        # There are 2 types of CSV file as following examples.
        # First, there is a header on first row and it's first column is "label".
        # Another, there is no header in the file.
        #
        # @example Load data from CSV file with header
        #   # test-data.csv:
        #   #  label,expected,target
        #   #  empty string,true,""
        #   #  plain string,false,hello
        #   #
        #   load_data("/path/to/test-data.csv")
        #   def test_empty?(data)
        #     assert_equal(data["expected"], data["target"].empty?)
        #   end
        #
        # @example Load data from CSV file without header
        #   # test-data-without-header.csv:
        #   #  empty string,true,""
        #   #  plain string,false,hello
        #   #
        #   load_data("/path/to/test-data-without-header.csv")
        #   def test_empty?(data)
        #     expected, target = data
        #     assert_equal(expected, target.empty?)
        #   end
        #
        class Loader
          # @api private
          def initialize(test_case)
            @test_case = test_case
          end

          # @api private
          def load(file_name)
            require 'csv'
            header = nil
            CSV.foreach(file_name) do |row|
              header = row if header.nil?
              label = nil

              if header.first == "label"
                next if header == row
                data = {}
                header.each_with_index do |key, i|
                  if key == "label"
                    label = row[i]
                  else
                    data[key] = normalize_value(row[i])
                  end
                end
              else
                label = row.shift
                data = row.collect do |cell|
                  normalize_value(cell)
                end
              end
              @test_case.data(label, data)
            end
          end

          private
          def normalize_value(value)
            return true if value == "true"
            return false if value == "false"
            begin
              Integer(value)
            rescue ArgumentError
              begin
                Float(value)
              rescue ArgumentError
                value
              end
            end
          end
        end
      end
    end
  end
end
