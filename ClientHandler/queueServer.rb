#queueServer.rb
# Handles all server interactions necessary for the Client Queue
# @author = Shad Scarboro
#---------------------------------------------------------------------------

# Existing Ruby Gems
require 'socket'
require 'json'

# Locally defined files/classes/modules
require 'clientQueue'

#---------------------------------------------------------------------------
class QueueServer

    # Basic initialization method
    # @param port [in] The port the TCP server will be opened on
    def initialize(port)
      #Start the server and start listening
      @q_server = TCPServer.open(port)
      @listenThread = Thread.new listenLoop
      @exit_loop = false
    end
    #---------------------------------------------------------------------------
    # Forces the message handling loop to exit
    def close
      exit_loop = true
    end

    #---------------------------------------------------------------------------

    # Execute the master messaging loop
    def listenLoop
      Socket.accept_loop(q_server) do |contact|
          puts "SERVER: Server recieved connection"
          begin
            communication = contact.recv(1024)
            puts "SERVER: Server recieved message: " + communication

            exit_loop = process_communication( communication, contact )

          rescue Exception => exp
            puts "#{ exp } (#{ exp.class })"
          ensure
            #Close the Socket
            contact.close
          end

        break if exit_loop
      end #end Socket.accept_loop(server) do |contact|

      Thread.exit
    end #end def listenLoop

    #---------------------------------------------------------------------------

    # Processes the recieved communication into a JSON message
    # @param communication [in] The message recieved from the socket
    # @param contact [out] The socket so that the processing can send responses
    # @return boolean, true if the master socket handling loop should exit
    # @param communication [in] The communication to be processed
    # @param contact [out] The socket so that the processing can send responses
    def process_communication ( communication, contact )

      if communication.length >= 2
        communication = JSON.parse( communication, create_additions: true )
        puts "SERVER: Message parsed into JSON: #{communication.class.name}"

        if communication.class.name == ClientCommunication.name
          #process_message
          puts "SERVER: Processing Client Message"
          process_message(communication, contact)
        else
          #Bad Communication
          puts "SERVER: ERROR! - Bad message from AgentProcessor - " + communication.class.name
        end #end if communication.class.name
      end
    end #end process_communication ( communication, contact )

    #---------------------------------------------------------------------------

    # Processes the JSON message and returns the appropriate response
    # @param msg [in] The JSON message to be processed
    # @param contact [out] The socket so that the processing can send responses
    def process_message ( msg, contact )

        case msg.message_body
        when ClientCommunication::request_client
          next_client = ClientQueue.pop

          #Convert to JSON
          json_message = create_out_message (next_client)

          #Send the message
          contact.send(json_message, 0)
        else
          puts "ERROR! - Unsupported message type - " + msg.message_body
        end #End case msg.message_body

    end # end process_message ( communication, contact )

    # Create a JSON response message.  Either a client or another message
    # @param next_client [in] The next client to be Sent
    # @return A JSON formatted message
    def create_out_message ( next_client )
      out_message = nil
      #If the next client is valid, send it along
      if next_client
        out_message = next_client

      #Check if the Queue has completed all of its processing for the day
      elsif ClientQueue.queue_completed
        out_message = ClientCommunication.new(ClientCommunication::begin_shutdown)
        exit_loop = true
      #Else return a NO_CLIENTS_WAITING message
      else
        out_message = ClientCommunication.new(ClientCommunication::no_clients_available)
      end
      return out_message.to_json
    end #end create_out_message
  end #end Class QueueServer