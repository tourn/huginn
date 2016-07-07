module Agents
  class DotaMatchAgent < Agent
    can_dry_run!
    cannot_be_scheduled!

    description <<-MD
      The Dota Match Agent will report the result of a dota match.
    MD

    event_description <<-MD
      The event will look like this:

          {
            "message": "Keel, Mario, Sandro lost All Random after 00:49:22. YASP Dotabuff"
          }
    MD

    def default_options
      {
        'format' => 'markdown',
        'player_names'  => {
          '38002544' => 'Bob',
          '56706937' => 'Jane'
        },
        'sites' => {
          'YASP' => 'http://yasp.co/matches/$',
          'Dotabuff' => 'http://www.dotabuff.com/matches/$)'
        }
      }
    end

    def validate_options
      errors.add(:base, "At least one player name is required") unless options['player_names'].present? and options['player_names'].size > 0

      options['player_names'].each do |id, name|
        Integer(id) rescue errors.add(:base, "Key of player name must be numeric")
      end if options['player_names'].respond_to? :each

      options['sites'].each do |name, url|
        errors.add(:base, "Url must contain a placeholder $ for match id") unless url.include? '$'
      end if options['sites'].respond_to? :each

      errors.add(:base, "Invalid format") unless ['markdown'].include? options['format']
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          result = event[:payload]
          fmt = format(result['result'])
          create_event :payload => {'message' => fmt}
        end
      end
    end

    #TODO probably move those into options
    GameModes = {
      0 => "None",
      1 => "All Pick",
      2 => "Captain's Mode",
      3 => "Random Draft",
      4 => "Single Draft",
      5 => "All Random",
      6 => "Intro",
      7 => "Diretide",
      8 => "Reverse Captain's Mode",
      9 => "The Greeviling",
      10 => "Tutorial",
      11 => "Mid Only",
      12 => "Least Played",
      13 => "New Player Pool",
      14 => "Compendium Matchmaking",
      16 => "Captains Draft",
      18 => "Ability Draft",
      20 => "All Random Death Match",
      21 => "1v1 Solo Mid",
      22 => "All Pick"
    }

    def format(match)
      players = filter_players(match)
      is_radiant = players.first['player_slot'] & 128 == 0
      player_names = players.map { |p| options['player_names'][p['account_id'].to_s] }.sort
      win = is_radiant == match['radiant_win']
      mode = GameModes[match['game_mode']]
      mode = "Ranked " + mode if match['lobby_type'] == 7
      time = format_time(match['duration'])
      id = match['match_id']

      "#{player_names.join(", ")} #{win ? "won" : "lost"} #{mode} after #{time}. " +
      format_sites(id) + '\n' +
      format_sprees(player_names, win)
    end

    def format_sites(match_id)
      options['sites'].map do |name, url|
        "[#{name}](#{url.sub('$', match_id.to_s)})"
      end.join(' ')
    end

    def format_sprees(player_names, win)
      spree = memory['spree'] || Hash.new(0)
      #could probably do this with reduce
      format = ""

      player_names.each do |name|
        if win
          spree[name] += 1
          format += format_spree(name, spree[name])
        else
          spree[name] = 0
        end
      end
      memory['spree'] = spree
      return format
    end

    def format_spree(player, spree)
      case spree
        when 0..2 then ""
        when 3 then "#{player} is on a Winning Spree!\n"
        when 4 then "#{player} is Dominating!\n"
        when 5 then "#{player} is on a Mega Win!\n"
        when 6 then "#{player} is Unstoppable!\n"
        when 7 then "#{player} is Wicked Sick!\n"
        when 8 then "#{player} is on a Monster Win!\n"
        when 9 then "#{player} is Godlike!\n"
        else "#{player}: Holy Shit!\n"
      end
    end

    def format_time(seconds)
      Time.at(seconds).utc.strftime("%H:%M:%S")
    end

    def filter_players(match)
      match['players'].select do |player|
        options['player_names'].include? player['account_id'].to_s
      end
    end
  end
end
