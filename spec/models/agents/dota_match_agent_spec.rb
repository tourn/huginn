
require 'rails_helper'

fdescribe Agents::DotaMatchAgent do
    before :each do
			@win = Event.new
			@win.agent = agents(:jane_weather_agent)
			@win.created_at = Time.now
			@win.payload = JSON.parse(open('spec/data_fixtures/dota_match_win.json').read) #Win: Bob Jane

			@loss = Event.new
			@loss.agent = agents(:jane_weather_agent)
			@loss.created_at = Time.now
			@loss.payload = JSON.parse(open('spec/data_fixtures/dota_match_loss.json').read) #Loss: Bob Jane
      @valid_options = {
        'format' => 'markdown',
        'player_names'	=> {
          '38002544' => 'Bob',
          '56706937' => 'Jane'
        },
        'sites' => {
          'YASP' => 'http://yasp.co/matches/$',
          'Dotabuff' => 'http://www.dotabuff.com/matches/$)'
        }
      }
      @checker = Agents::DotaMatchAgent.new(:name => "dota", :options => @valid_options, :keep_events_for => 2.days)
      @checker.user = users(:bob)
      @checker.save!
    end

    describe 'validation' do
      before do
        expect(@checker).to be_valid
      end

      describe 'of player names' do
        it 'checks for presence' do
          @checker.options['player_names'] = ""
          expect(@checker).not_to be_valid
          @checker.options['player_names'] = {}
          expect(@checker).not_to be_valid
        end

        it 'verifies the id is numeric' do
          @checker.options['player_names'] = {"foo" => "bar"}
          expect(@checker).not_to be_valid
        end
      end

      it 'verifies that sites contain a placeholder' do
          @checker.options['sites'] = {"foo" => "http://bar"}
          expect(@checker).not_to be_valid
      end

      it 'verifies the format' do
        @checker.options['format'] = "hans"
        expect(@checker).not_to be_valid
      end
    end

    describe '#receive' do
      it 'formats a win' do
        @checker.receive([@win])
        expect(Event.last.payload[:message]).to include "Bob, Jane won"
      end

      it 'formats a loss' do
        @checker.receive([@loss])
        expect(Event.last.payload[:message]).to include "Bob, Jane lost"
      end

      it 'formats a winning spree' do
        @checker.receive([@win])
        @checker.receive([@win])
        @checker.receive([@win])
        expect(Event.last.payload[:message]).to include "Bob is on a Winning Spree!"
      end

      it 'properly resets winning sprees on loss' do
        @checker.receive([@win])
        @checker.receive([@win])
        @checker.receive([@win])
        @checker.receive([@loss])
        expect(Event.last.payload[:message]).not_to include "Bob is on a Winning Spree!"
      end

      it 'formats configured sites' do
        @checker.receive([@win])
        expect(Event.last.payload[:message]).to include "[YASP](http://yasp.co/matches/1941749516)"
        expect(Event.last.payload[:message]).to include "[Dotabuff](http://www.dotabuff.com/matches/1941749516)"
      end
    end
end
