import unittest
import requests
import json
import time

API_URL = "http://127.0.0.1:8000"

class TestModoSala(unittest.TestCase):
    def test_live_quiz_flow(self):
        print("\n--- INICIANDO TESTE DO MODO SALA ---")
        
        # Test User IDs
        gestor_id = "gestor-test-uuid-123"
        user1_id = "user1-test-uuid-456"
        user2_id = "user2-test-uuid-789"
        
        # 1. GESTOR CRIA SALA
        print("\n1. Criando sala ao vivo...")
        payload = {
            "empresa_id": "empresa-test-uuid",
            "criado_por_usuario_id": gestor_id,
            "tipo": "gestor",
            "origem_perguntas": "personalizada"
        }
        res = requests.post(f"{API_URL}/api/sala/criar", json=payload)
        self.assertIn(res.status_code, [200, 201])
        
        sala = res.json()
        codigo = sala["codigo"]
        sala_id = sala["id"]
        print(f"Sala criada com sucesso! Código: {codigo}, ID: {sala_id}")
        
        self.assertEqual(sala["status"], "aguardando")
        self.assertEqual(len(codigo), 6)

        # 2. ADICIONAR PERGUNTAS PERSONALIZADAS
        print("\n2. Adicionando 3 perguntas personalizadas...")
        perguntas_payload = {
            "perguntas": [
                {
                    "texto": "Pergunta 1?",
                    "alternativa_a": "Incorreta",
                    "alternativa_b": "Correta",
                    "alternativa_c": "Incorreta",
                    "alternativa_d": "Incorreta",
                    "resposta_correta": "B"
                },
                {
                    "texto": "Pergunta 2?",
                    "alternativa_a": "Correta",
                    "alternativa_b": "Incorreta",
                    "alternativa_c": "Incorreta",
                    "alternativa_d": "Incorreta",
                    "resposta_correta": "A"
                },
                {
                    "texto": "Pergunta 3?",
                    "alternativa_a": "Incorreta",
                    "alternativa_b": "Incorreta",
                    "alternativa_c": "Incorreta",
                    "alternativa_d": "Correta",
                    "resposta_correta": "D"
                }
            ]
        }
        res_perguntas = requests.post(f"{API_URL}/api/sala/{codigo}/adicionar-perguntas", json=perguntas_payload)
        self.assertEqual(res_perguntas.status_code, 200)
        
        perguntas = res_perguntas.json()["perguntas"]
        self.assertEqual(len(perguntas), 3)
        print("Perguntas associadas à sala com sucesso!")

        # 3. DOIS USUÁRIOS DE TESTE ENTRAM COM O CÓDIGO
        print("\n3. Colaboradores entrando na sala...")
        res_join1 = requests.post(f"{API_URL}/api/sala/{codigo}/entrar", json={"usuario_id": user1_id})
        self.assertEqual(res_join1.status_code, 200)
        part1 = res_join1.json()["participante"]
        print(f"Usuário 1 entrou. ID do Participante: {part1['id']}")

        res_join2 = requests.post(f"{API_URL}/api/sala/{codigo}/entrar", json={"usuario_id": user2_id})
        self.assertEqual(res_join2.status_code, 200)
        part2 = res_join2.json()["participante"]
        print(f"Usuário 2 entrou. ID do Participante: {part2['id']}")

        # 4. GESTOR INICIA A SALA
        print("\n4. Iniciando a partida...")
        res_start = requests.post(f"{API_URL}/api/sala/{codigo}/iniciar")
        self.assertEqual(res_start.status_code, 200)
        sala_iniciada = res_start.json()
        self.assertEqual(sala_iniciada["status"], "em_andamento")
        self.assertEqual(sala_iniciada["pergunta_atual_index"], 0)
        print("Partida iniciada!")

        # 5. AMBOS RESPONDEM AS PERGUNTAS (Pergunta 1, Correta = B)
        # Usuário 1 responde rápido (1.5s), correto = B
        # Usuário 2 responde devagar (10s), correto = B
        print("\n5. Respondendo pergunta 1...")
        p1 = perguntas[0]
        
        # User 1
        res_ans1 = requests.post(f"{API_URL}/api/sala/{codigo}/responder", json={
            "usuario_id": user1_id,
            "pergunta_id": p1["id"],
            "alternativa_escolhida": "B",
            "tempo_resposta_ms": 1500
        })
        self.assertEqual(res_ans1.status_code, 200)
        ans1_data = res_ans1.json()
        self.assertTrue(ans1_data["correta"])
        print(f"Usuário 1 respondeu correto! Ganhou {ans1_data['pontos_ganhos']} pontos.")

        # User 2
        res_ans2 = requests.post(f"{API_URL}/api/sala/{codigo}/responder", json={
            "usuario_id": user2_id,
            "pergunta_id": p1["id"],
            "alternativa_escolhida": "B",
            "tempo_resposta_ms": 10000
        })
        self.assertEqual(res_ans2.status_code, 200)
        ans2_data = res_ans2.json()
        self.assertTrue(ans2_data["correta"])
        print(f"Usuário 2 respondeu correto! Ganhou {ans2_data['pontos_ganhos']} pontos.")
        
        # User 1 should have more points due to faster answer
        self.assertGreater(ans1_data["pontos_ganhos"], ans2_data["pontos_ganhos"])

        # 6. GESTOR AVANÇA PARA PERGUNTA 2
        print("\n6. Avançando para pergunta 2...")
        res_next = requests.post(f"{API_URL}/api/sala/{codigo}/proxima-pergunta")
        self.assertEqual(res_next.status_code, 200)
        self.assertEqual(res_next.json()["pergunta_atual_index"], 1)

        # 7. RESPONDER PERGUNTA 2 (Correta = A)
        # Usuário 1 responde correto (5s), correto = A
        # Usuário 2 responde incorreto (2s), incorreto = C
        print("\n7. Respondendo pergunta 2...")
        p2 = perguntas[1]
        
        res_ans2_1 = requests.post(f"{API_URL}/api/sala/{codigo}/responder", json={
            "usuario_id": user1_id,
            "pergunta_id": p2["id"],
            "alternativa_escolhida": "A",
            "tempo_resposta_ms": 5000
        })
        self.assertTrue(res_ans2_1.json()["correta"])

        res_ans2_2 = requests.post(f"{API_URL}/api/sala/{codigo}/responder", json={
            "usuario_id": user2_id,
            "pergunta_id": p2["id"],
            "alternativa_escolhida": "C",
            "tempo_resposta_ms": 2000
        })
        self.assertFalse(res_ans2_2.json()["correta"])
        self.assertEqual(res_ans2_2.json()["pontos_ganhos"], 0)
        print("Respostas registradas para Pergunta 2.")

        # 8. AVANÇAR E RESPONDER PERGUNTA 3 (Correta = D)
        # Ambos respondem correto
        print("\n8. Avançando e respondendo pergunta 3...")
        requests.post(f"{API_URL}/api/sala/{codigo}/proxima-pergunta")
        p3 = perguntas[2]
        
        requests.post(f"{API_URL}/api/sala/{codigo}/responder", json={
            "usuario_id": user1_id,
            "pergunta_id": p3["id"],
            "alternativa_escolhida": "D",
            "tempo_resposta_ms": 3000
        })
        requests.post(f"{API_URL}/api/sala/{codigo}/responder", json={
            "usuario_id": user2_id,
            "pergunta_id": p3["id"],
            "alternativa_escolhida": "D",
            "tempo_resposta_ms": 3000
        })

        # 9. GESTOR FINALIZA SALA
        print("\n9. Finalizando a sala e verificando ranking final...")
        res_final = requests.post(f"{API_URL}/api/sala/{codigo}/finalizar")
        self.assertEqual(res_final.status_code, 200)
        
        final_data = res_final.json()
        self.assertEqual(final_data["sala"]["status"], "finalizada")
        
        participantes_finais = final_data["participantes"]
        self.assertEqual(len(participantes_finais), 2)
        
        # O usuário 1 deve estar em 1º lugar e o usuário 2 em 2º lugar
        # devido a mais acertos e maior rapidez
        self.assertEqual(participantes_finais[0]["usuario_id"], user1_id)
        self.assertEqual(participantes_finais[0]["posicao_final"], 1)
        self.assertEqual(participantes_finais[1]["usuario_id"], user2_id)
        self.assertEqual(participantes_finais[1]["posicao_final"], 2)
        
        print(f"Ranking final validado com sucesso!")
        print(f"1º Lugar: {participantes_finais[0]['usuario_id']} ({participantes_finais[0]['pontuacao_total']} pts)")
        print(f"2º Lugar: {participantes_finais[1]['usuario_id']} ({participantes_finais[1]['pontuacao_total']} pts)")
        
        # 10. VERIFICAR ESTATÍSTICAS DA SALA
        print("\n10. Consultando estatísticas da sala...")
        res_stats = requests.get(f"{API_URL}/api/sala/{codigo}/estatisticas")
        self.assertEqual(res_stats.status_code, 200)
        stats_list = res_stats.json()
        self.assertEqual(len(stats_list), 3)
        print("Estatísticas geradas:")
        for idx, s in enumerate(stats_list):
            print(f"Pergunta {idx+1}: {s['total_respostas']} respostas, {s['corretas']} acertos ({s['taxa_acerto']}% acerto)")

        print("\n--- TESTE FINALIZADO COM SUCESSO! ---")

if __name__ == "__main__":
    unittest.main()
