
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
          'YASP' => 'http://yasp.co/matches/#',
          'Dotabuff' => 'http://www.dotabuff.com/matches/#)'
        }
      }
      @checker = Agents::DotaMatchAgent.new(:name => "dota", :options => @valid_options, :keep_events_for => 2.days)
      @checker.user = users(:bob)
      @checker.save!
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
